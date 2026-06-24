import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

  test('polls queued and processing server jobs before downloading', () {
    fakeAsync((async) {
      final targetDirectory = Directory.systemTemp.createTempSync(
        'thesis-reader-package-',
      );
      addTearDown(() => targetDirectory.deleteSync(recursive: true));
      final fallback = RecordingOnDeviceConverter();
      final server = PollingServerClient();
      final orchestrator = ConversionOrchestrator(
        serverClient: server,
        fallbackConverter: fallback,
        serverTimeout: const Duration(seconds: 10),
        pollInterval: const Duration(milliseconds: 10),
        packageDirectory: targetDirectory,
      );
      ConversionResult? result;

      orchestrator
          .start(File('paper.pdf'), documentId: 'doc-1')
          .then((value) => result = value);

      async.flushMicrotasks();
      expect(result, isNull);

      async.elapse(const Duration(milliseconds: 10));
      async.flushMicrotasks();
      expect(result, isNull);

      async.elapse(const Duration(milliseconds: 10));
      async.flushMicrotasks();

      expect(fallback.called, isFalse);
      expect(server.getJobCalls, 2);
      expect(server.downloadCalls, 1);
      expect(
        result?.packagePath,
        p.join(targetDirectory.path, 'job-1', 'package.json'),
      );
      expect(result?.source, ConversionSource.server);
    });
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

class PollingServerClient implements ConverterClient {
  int getJobCalls = 0;
  int downloadCalls = 0;

  @override
  Future<ConverterJob> createJob(File pdf) async {
    return const ConverterJob(
      jobId: 'job-1',
      status: ConverterJobStatus.queued,
    );
  }

  @override
  Future<File> downloadPackage(String jobId, Directory targetDirectory) async {
    downloadCalls += 1;
    return File(p.join(targetDirectory.path, jobId, 'package.json'));
  }

  @override
  Future<ConverterJobStatus> getJob(String jobId) async {
    getJobCalls += 1;
    return getJobCalls == 1
        ? ConverterJobStatus.processing
        : ConverterJobStatus.succeeded;
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
