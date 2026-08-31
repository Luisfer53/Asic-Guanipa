import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'session_storage_stub.dart'
    if (dart.library.html) 'session_storage_web.dart';

final secureStorage = const FlutterSecureStorage(
  webOptions: WebOptions(
    dbName: 'asic_guanipa_storage',
    publicKey: 'asic_guanipa_key',
  ),
);

Future<void> saveToken(String token) async {
  if (kIsWeb) {
    setSessionToken(token);
  } else {
    try {
      await secureStorage.write(key: 'jwt', value: token);
    } catch (e) {
      debugPrint('Error saving token: $e');
    }
  }
}

Future<String?> getToken() async {
  if (kIsWeb) {
    final t = getSessionToken();
    if (t != null && t.isNotEmpty) {
      return t;
    }
    return null;
  } else {
    try {
      return await secureStorage.read(key: 'jwt');
    } catch (e) {
      debugPrint('Error reading token: $e');
      return null;
    }
  }
}

Future<void> deleteToken() async {
  if (kIsWeb) {
    removeSessionToken();
  } else {
    try {
      await secureStorage.delete(key: 'jwt');
    } catch (e) {
      debugPrint('Error deleting token: $e');
    }
  }
}
