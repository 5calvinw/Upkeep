import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/features/tickets/data/models/ticket.dart';
import 'package:frontend/core/constants.dart';

class GoogleAccountNotRegisteredException implements Exception {
  const GoogleAccountNotRegisteredException({
    required this.email,
    required this.message,
  });

  final String email;
  final String message;

  @override
  String toString() => message;
}

class AuthService {
  static const String _baseUrl = kBaseUrl;
  static const String _tokenKey = 'access_token';
  static const String _cachedUserKey = 'cached_user';

  static final ValueNotifier<UserInfo?> currentUser = ValueNotifier(null);
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static Future<void>? _googleInitializeFuture;

  static bool get isGoogleLoginAvailable =>
      kIsWeb && kGoogleWebClientId.isNotEmpty;

  static GoogleSignIn get googleSignIn => _googleSignIn;

  static Future<void> init() async {
    final user = await AuthService()._getCachedUserInternal();
    currentUser.value = user;
    await initializeGoogleSignIn();
  }

  static Future<void> initializeGoogleSignIn() {
    if (!isGoogleLoginAvailable) {
      return Future.value();
    }

    return _googleInitializeFuture ??= _googleSignIn.initialize(
      clientId: kGoogleWebClientId,
    );
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    await _storeSessionFromResponse(response, fallbackError: 'Login failed');
  }

  Future<void> loginWithGoogleAccount(GoogleSignInAccount account) async {
    final auth = account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google login did not return an ID token');
    }

    await loginWithGoogleIdToken(idToken);
  }

  Future<void> loginWithGoogleIdToken(String idToken) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    await _storeSessionFromResponse(
      response,
      fallbackError: 'Google login failed',
    );
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
      await login(email, password);
    } else {
      throw Exception(
        _parseErrorMessage(response.body, fallback: 'Registration failed'),
      );
    }
  }

  Future<void> _storeSessionFromResponse(
    http.Response response, {
    required String fallbackError,
  }) async {
    if (response.statusCode != 200) {
      final parsed = _parseErrorPayload(response.body);
      final detail = parsed['detail'];

      if (detail is Map<String, dynamic> &&
          detail['code'] == 'google_account_not_registered') {
        throw GoogleAccountNotRegisteredException(
          email: (detail['email'] as String?) ?? '',
          message:
              (detail['message'] as String?) ??
              'No Upkeep account exists for this Google email',
        );
      }

      throw Exception(
        _parseErrorMessage(response.body, fallback: fallbackError),
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await _loadAndCacheUser(token);
  }

  Future<void> _loadAndCacheUser(String token) async {
    final userResp = await http.get(
      Uri.parse('$_baseUrl/users/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (userResp.statusCode != 200) {
      throw Exception('Failed to load authenticated user');
    }

    final user = UserInfo.fromJson(jsonDecode(userResp.body));
    await _cacheUser(user);
    currentUser.value = user;
  }

  Map<String, dynamic> _parseErrorPayload(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Fall back to plain-text error handling below.
    }
    return const {};
  }

  String _parseErrorMessage(String body, {required String fallback}) {
    final decoded = _parseErrorPayload(body);
    final detail = decoded['detail'];

    if (detail is String && detail.isNotEmpty) {
      return detail;
    }

    if (detail is Map<String, dynamic>) {
      final message = detail['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }

    return fallback;
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
    currentUser.value = null;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
