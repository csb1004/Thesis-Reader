import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:thesis_reader/features/library/data/converter_client.dart';

void main() {
  test('createJob uploads the PDF as multipart field file', () async {
    http.MultipartRequest? capturedRequest;
    final client = HttpConverterClient(
      baseUri: Uri.parse('http://converter.test'),
      httpClient: HandlerClient((request) {
        capturedRequest = request as http.MultipartRequest;
        return jsonResponse({'jobId': 'job-1', 'status': 'queued'});
      }),
    );
    final pdf = _tempFile('paper.pdf', [1, 2, 3]);

    final job = await client.createJob(pdf);

    expect(job.jobId, 'job-1');
    expect(job.status, ConverterJobStatus.queued);
    expect(capturedRequest?.method, 'POST');
    expect(capturedRequest?.url.path, '/jobs');
    expect(capturedRequest?.files, hasLength(1));
    expect(capturedRequest?.files.single.field, 'file');
  });

  test('getJob parses status values from server payloads', () async {
    final client = HttpConverterClient(
      baseUri: Uri.parse('http://converter.test'),
      httpClient: HandlerClient((request) {
        expect(request.method, 'GET');
        expect(request.url.path, '/jobs/job-1');
        return jsonResponse({'status': 'processing'});
      }),
    );

    final status = await client.getJob('job-1');

    expect(status, ConverterJobStatus.processing);
  });

  test('downloadPackage extracts zip and returns package.json', () async {
    final zipBytes = ZipEncoder().encode(
      Archive()
        ..addFile(_archiveFile('package.json', '{"pages": []}'))
        ..addFile(_archiveFile('assets/page-1.txt', 'hello')),
    )!;
    final client = HttpConverterClient(
      baseUri: Uri.parse('http://converter.test'),
      httpClient: HandlerClient((request) {
        expect(request.method, 'GET');
        expect(request.url.path, '/jobs/job-1/download');
        return http.StreamedResponse(
          Stream.value(zipBytes),
          200,
          headers: {'content-type': 'application/zip'},
        );
      }),
    );
    final targetDirectory = Directory.systemTemp.createTempSync(
      'thesis-reader-client-',
    );
    addTearDown(() => targetDirectory.deleteSync(recursive: true));

    final packageFile = await client.downloadPackage('job-1', targetDirectory);

    expect(
      packageFile.path,
      p.join(targetDirectory.path, 'job-1', 'package.json'),
    );
    expect(await packageFile.readAsString(), '{"pages": []}');
    expect(
      await File(
        p.join(targetDirectory.path, 'job-1', 'assets', 'page-1.txt'),
      ).readAsString(),
      'hello',
    );
  });

  test('throws ConverterClientException on non-2xx responses', () async {
    final client = HttpConverterClient(
      baseUri: Uri.parse('http://converter.test'),
      httpClient: HandlerClient((request) {
        return http.StreamedResponse(
          Stream.value(utf8.encode('server exploded')),
          500,
        );
      }),
    );

    expect(
      () => client.getJob('job-1'),
      throwsA(
        isA<ConverterClientException>()
            .having((error) => error.statusCode, 'statusCode', 500)
            .having((error) => error.body, 'body', 'server exploded'),
      ),
    );
  });
}

class HandlerClient extends http.BaseClient {
  HandlerClient(this.handler);

  final FutureOr<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return handler(request);
  }
}

http.StreamedResponse jsonResponse(Map<String, Object?> payload) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(payload))),
    200,
    headers: {'content-type': 'application/json'},
  );
}

ArchiveFile _archiveFile(String name, String content) {
  final bytes = utf8.encode(content);
  return ArchiveFile(name, bytes.length, bytes);
}

File _tempFile(String name, List<int> bytes) {
  final directory = Directory.systemTemp.createTempSync('thesis-reader-pdf-');
  final file = File(p.join(directory.path, name))..writeAsBytesSync(bytes);
  addTearDown(() => directory.deleteSync(recursive: true));
  return file;
}
