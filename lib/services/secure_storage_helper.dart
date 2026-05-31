import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageHelper {
  final _storage = const FlutterSecureStorage();
  final String _pinKey = 'user_secure_pin';

  // Save the PIN after they create it
  Future<void> savePin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  // Read the PIN when they open the app
  Future<String?> getPin() async {
    return await _storage.read(key: _pinKey);
  }

  // Delete the PIN if they log out completely
  Future<void> deletePin() async {
    await _storage.delete(key: _pinKey);
  }
}