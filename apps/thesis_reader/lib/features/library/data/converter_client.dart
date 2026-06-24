import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

abstract interface class ConverterClient {
  Future<ConverterJob> createJob(File pdf);
  Future<ConverterJobStatus> getJob(String jobId);
  Future<File> downloadPackage(String jobId, Directory targetDirectory);
}

class ConverterJob {
  const ConverterJob({required this.jobId, required this.status});

  final String jobId;
  final ConverterJobStatus status;
}

enum ConverterJobStatus { queued, processing, succeeded, failed }

ConverterJobStatus parseConverterJobStatus(String value) {
  return switch (value) {
    'queued' => ConverterJobStatus.queued,
    'processing' => ConverterJobStatus.processing,
    'succeeded' => ConverterJobStatus.succeeded,
    'failed' => ConverterJobStatus.failed,
    _ => throw FormatException('Unknown converter job status: $value'),
  };
}

class HttpConverterClient implements ConverterClient {
  HttpConverterClient({required Uri baseUri, http.Client? httpClient})
    : _baseUri = baseUri,
      _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _httpClient;

  @override
  Future<ConverterJob> createJob(File pdf) async {
    final request = http.MultipartRequest('POST', _baseUri.resolve('/jobs'))
      ..files.add(await http.MultipartFile.fromPath('file', pdf.path));

    final response = await _httpClient.send(request);
    final body = await response.stream.bytesToString();
    _throwIfUnsuccessful(response.statusCode, body);

    final payload = _decodeJsonObject(body);
    return ConverterJob(
      jobId: _readString(payload, 'jobId', fallbackKey: 'id'),
      status: parseConverterJobStatus(_readString(payload, 'status')),
    );
  }

  @override
  Future<ConverterJobStatus> getJob(String jobId) async {
    final response = await _httpClient.get(_baseUri.resolve('/jobs/$jobId'));
    _throwIfUnsuccessful(response.statusCode, response.body);

    final payload = _decodeJsonObject(response.body);
    return parseConverterJobStatus(_readString(payload, 'status'));
  }

  @override
  Future<File> downloadPackage(String jobId, Directory targetDirectory) async {
    final response = await _httpClient.get(
      _baseUri.resolve('/jobs/$jobId/download'),
    );
    _throwIfUnsuccessful(response.statusCode, response.body);

    final packageDirectory = Directory(p.join(targetDirectory.path, jobId));
    await packageDirectory.create(recursive: true);

    final archive = ZipDecoder().decodeBytes(response.bodyBytes);
    for (final archiveFile in archive.files) {
      if (!archiveFile.isFile) {
        continue;
      }

      final outputFile = File(
        p.joinAll([
          packageDirectory.path,
          ..._safeArchivePathSegments(archiveFile.name),
        ]),
      );
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(archiveFile.content as List<int>);
    }

    final packageFile = File(p.join(packageDirectory.path, 'package.json'));
    if (!packageFile.existsSync()) {
      throw const FormatException('Converter package zip missing package.json');
    }

    return packageFile;
  }

  void close() => _httpClient.close();

  Map<String, Object?> _decodeJsonObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded case final Map<String, Object?> payload) {
      return payload;
    }

    throw const FormatException(
      'Expected converter response to be a JSON object',
    );
  }

  String _readString(
    Map<String, Object?> payload,
    String key, {
    String? fallbackKey,
  }) {
    final value =
        payload[key] ?? (fallbackKey == null ? null : payload[fallbackKey]);
    if (value is String && value.isNotEmpty) {
      return value;
    }

    throw FormatException('Expected converter response field "$key"');
  }

  void _throwIfUnsuccessful(int statusCode, String body) {
    if (statusCode >= 200 && statusCode < 300) {
      return;
    }

    throw ConverterClientException(statusCode: statusCode, body: body);
  }

  List<String> _safeArchivePathSegments(String archivePath) {
    final normalized = p.url.normalize(archivePath.replaceAll(r'\', '/'));
    if (p.url.isAbsolute(normalized) ||
        normalized == '..' ||
        normalized.startsWith('../')) {
      throw FormatException('Unsafe converter package path: $archivePath');
    }

    return normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
  }
}

class ConverterClientException implements Exception {
  const ConverterClientException({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;

  @override
  String toString() => 'ConverterClientException($statusCode): $body';
}
