import 'dart:convert';
import 'dart:io';

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
      ..files.add(await http.MultipartFile.fromPath('pdf', pdf.path));

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

    await targetDirectory.create(recursive: true);
    final packageFile = File(
      p.join(targetDirectory.path, '$jobId-package.json'),
    );
    return packageFile.writeAsBytes(response.bodyBytes);
  }

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
