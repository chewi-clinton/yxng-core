import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

class AuthService extends ChangeNotifier {
  final _secureStorage = const FlutterSecureStorage();
  bool isAuthenticated = false;
  String? username;

  Future<void> checkAuth() async {
    final token = await _secureStorage.read(key: 'auth_token');
    username = await _secureStorage.read(key: 'username');
    isAuthenticated = token != null;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await apiClient.post(
        '/auth/login/',
        data: {'username': username, 'password': password},
      );
      final token = response.data['token'];
      await _secureStorage.write(key: 'auth_token', value: token);
      await _secureStorage.write(key: 'username', value: username);
      this.username = username;
      isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> register(
    String username,
    String email,
    String password,
  ) async {
    try {
      final response = await apiClient.post(
        '/auth/register/',
        data: {'username': username, 'email': email, 'password': password},
      );
      final token = response.data['token'];
      final returnedUsername = response.data['username'] ?? username;
      await _secureStorage.write(key: 'auth_token', value: token);
      await _secureStorage.write(key: 'username', value: returnedUsername);
      this.username = returnedUsername;
      isAuthenticated = true;
      notifyListeners();
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data.isNotEmpty) {
        final firstError = data.values.first;
        return firstError is List ? firstError.first.toString() : firstError.toString();
      }
      return 'Could not reach the server.';
    } catch (_) {
      return 'Could not reach the server.';
    }
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'username');
    username = null;
    isAuthenticated = false;
    notifyListeners();
  }
}
