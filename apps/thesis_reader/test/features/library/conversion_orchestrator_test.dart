import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/features/library/data/conversion_orchestrator.dart';
import 'package:thesis_reader/features/library/data/converter_client.dart';
import 'package:thesis_reader/features/library/data/on_device_converter.dart';

void main() {
  test('parses converter job status values from server payloads', () {
    expect(parseConverterJobStatus('queued'), ConverterJobStatus.queued);
    expect(
      parseConverterJobStatus('processing'),
      ConverterJobStatus.processing,
    );
    expect(parseConverterJobStatus('succeeded'), ConverterJobStatus.succeeded);
    expect(parseConverterJobStatus('failed'), ConverterJobStatus.failed);
  });

  test(
    'falls back to on-device conversion when server job creation times out',
    () {
      fakeAsync((async) {
        final fallback = RecordingOnDeviceConverter();
        final orchestrator = ConversionOrchestrator(
          serverClient: HangingServerClient(),
          fallbackConverter: fallback,
          serverTimeout: const Duration(seconds: 10),
        );
        ConversionResult? result;

        orchestrator
            .start(File('paper.pdf'), documentId: 'doc-1')
            .then((value) => result = value);

        async.elapse(const Duration(seconds: 11));
        async.flushMicrotasks();

        expect(fallback.called, isTrue);
        expect(result?.packagePath, 'local/package.json');
        expect(result?.source, ConversionSource.onDevice);
      });
    },
  );

  test(
    'falls back to on-device conversion when server job creation fails',
    () async {
      final fallback = RecordingOnDeviceConverter();
      final orchestrator = ConversionOrchestrator(
        serverClient: ThrowingServerClient(),
        fallbackConverter: fallback,
      );

      final result = await orchestrator.start(
        File('paper.pdf'),
        documentId: 'doc-1',
      );

      expect(fallback.called, isTrue);
      expect(result.packagePath, 'local/package.json');
      expect(result.source, ConversionSource.onDevice);
    },
  );

  test('falls back to on-device conversion when server job fails', () async {
    final fallback = RecordingOnDeviceConverter();
    final orchestrator = ConversionOrchestrator(
      serverClient: FailedJobServerClient(),
      fallbackConverter: fallback,
    );

    final result = await orchestrator.start(
      File('paper.pdf'),
      documentId: 'doc-1',
    );

    expect(fallback.called, isTrue);
    expect(result.packagePath, 'local/package.json');
    expect(result.source, ConversionSource.onDevice);
  });
}

class HangingServerClient implements ConverterClient {
  @override
  Future<ConverterJob> createJob(File pdf) => Completer<ConverterJob>().future;

  @override
  Future<File> downloadPackage(String jobId, Directory targetDirectory) {
    throw UnimplementedError();
  }

  @override
  Future<ConverterJobStatus> getJob(String jobId) {
    throw UnimplementedError();
  }
}

class ThrowingServerClient implements ConverterClient {
  @override
  Future<ConverterJob> createJob(File pdf) =>
      Future.error(Exception('server down'));

  @override
  Future<File> downloadPackage(String jobId, Directory targetDirectory) {
    throw UnimplementedError();
  }

  @override
  Future<ConverterJobStatus> getJob(String jobId) {
    throw UnimplementedError();
  }
}

class FailedJobServerClient implements ConverterClient {
  @override
  Future<ConverterJob> createJob(File pdf) async {
    return const ConverterJob(
      jobId: 'job-1',
      status: ConverterJobStatus.failed,
    );
  }

  @override
  Future<File> downloadPackage(String jobId, Directory targetDirectory) {
    throw UnimplementedError();
  }

  @override
  Future<ConverterJobStatus> getJob(String jobId) {
    throw UnimplementedError();
  }
}

class RecordingOnDeviceConverter implements OnDeviceConverter {
  bool called = false;

  @override
  Future<ConversionResult> convert(File pdf, String documentId) async {
    called = true;
    return const ConversionResult(
      packagePath: 'local/package.json',
      source: ConversionSource.onDevice,
    );
  }
}
