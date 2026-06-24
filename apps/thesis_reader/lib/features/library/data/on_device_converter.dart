import 'dart:io';

abstract interface class OnDeviceConverter {
  Future<ConversionResult> convert(File pdf, String documentId);
}

class ConversionResult {
  const ConversionResult({
    required this.packagePath,
    this.source = ConversionSource.server,
  });

  final String packagePath;
  final ConversionSource source;
}

enum ConversionSource { server, onDevice }
