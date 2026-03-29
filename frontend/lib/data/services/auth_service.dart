import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ticket.dart';
import '../../core/constants.dart';

class AuthService {
  static const String _baseUrl = kBaseUrl;
  static const String _tokenKey = 'access_token';
  static const String _cachedUserKey = 'cached_user';

  /// Shared notifier — go_router uses this as refreshListenable.
  static final ValueNotifier<UserInfo?> currentUser = ValueNotifier(null);

  /// Call once at app startup to restore cached auth state.
  static Future<void> init() async {
    final user = await AuthService()._getCachedUserInternal();
    currentUser.value = user;
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['access_token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);

      // Fetch and cache the user immediately after storing the token.
      final userResp = await http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      if (userResp.statusCode == 200) {
        final user = UserInfo.fromJson(jsonDecode(userResp.body));
        await _cacheUser(user);
        AuthService.currentUser.value = user;
      }
    } else {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(error['detail'] ?? 'Login failed');
    }
  }

  Future<void> register(
    String inviteToken,
    String email,
    String password,
    String fullName,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'invite_token': inviteToken,
        'email': email,
        'password': password,
        'full_name': fullName,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      // Auto-login after registration.
      await login(email, password);
    } else {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(error['detail'] ?? 'Registration failed');
    }
  }

  Future<void> _cacheUser(UserInfo user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedUserKey, jsonEncode(user.toJson()));
  }

  Future<UserInfo?> _getCachedUserInternal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedUserKey);
    if (raw == null) return null;
    try {
      return UserInfo.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<UserInfo?> getCachedUser() => _getCachedUserInternal();

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_cachedUserKey);
    AuthService.currentUser.value = null;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
