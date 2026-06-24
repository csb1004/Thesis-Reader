import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class OpenAiKeyReader {
  Future<String?> readKey();
}

class OpenAiKeyStore implements OpenAiKeyReader {
  OpenAiKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const keyName = 'openai_api_key';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readKey() => _storage.read(key: keyName);

  Future<void> writeKey(String apiKey) {
    return _storage.write(key: keyName, value: apiKey.trim());
  }

  Future<void> deleteKey() => _storage.delete(key: keyName);

  Future<void> clear() => deleteKey();
}
