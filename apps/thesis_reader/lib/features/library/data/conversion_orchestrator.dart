import 'dart:async';
import 'dart:io';

import 'package:thesis_reader/features/library/data/converter_client.dart';
import 'package:thesis_reader/features/library/data/on_device_converter.dart';

class ConversionOrchestrator {
  ConversionOrchestrator({
    required ConverterClient serverClient,
    required OnDeviceConverter fallbackConverter,
    Duration serverTimeout = const Duration(seconds: 10),
    Duration pollInterval = const Duration(milliseconds: 500),
    Directory? packageDirectory,
  }) : _serverClient = serverClient,
       _fallbackConverter = fallbackConverter,
       _serverTimeout = serverTimeout,
       _pollInterval = pollInterval,
       _packageDirectory = packageDirectory;

  final ConverterClient _serverClient;
  final OnDeviceConverter _fallbackConverter;
  final Duration _serverTimeout;
  final Duration _pollInterval;
  final Directory? _packageDirectory;

  Future<ConversionResult> start(File pdf, {required String documentId}) async {
    try {
      return await _convertWithServer(pdf, documentId).timeout(_serverTimeout);
    } on Exception {
      return _fallbackConverter.convert(pdf, documentId);
    }
  }

  Future<ConversionResult> _convertWithServer(
    File pdf,
    String documentId,
  ) async {
    final job = await _serverClient.createJob(pdf);
    if (job.status == ConverterJobStatus.failed) {
      throw ConversionServerException('Converter job failed: ${job.jobId}');
    }

    var status = job.status;
    while (status == ConverterJobStatus.queued ||
        status == ConverterJobStatus.processing) {
      await Future<void>.delayed(_pollInterval);
      status = await _serverClient.getJob(job.jobId);
    }

    if (status == ConverterJobStatus.failed) {
      throw ConversionServerException('Converter job failed: ${job.jobId}');
    }

    final package = await _serverClient.downloadPackage(
      job.jobId,
      _packageDirectory ?? pdf.parent,
    );
    return ConversionResult(
      packagePath: package.path,
      source: ConversionSource.server,
    );
  }
}

class ConversionServerException implements Exception {
  const ConversionServerException(this.message);

  final String message;

  @override
  String toString() => 'ConversionServerException: $message';
}
