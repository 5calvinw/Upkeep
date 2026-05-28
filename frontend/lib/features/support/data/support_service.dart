import 'dart:convert';
import 'dart:typed_data';

import 'package:frontend/core/constants.dart';
import 'package:frontend/features/auth/data/auth_service.dart';
import 'package:frontend/features/support/data/support_models.dart';
import 'package:http/http.dart' as http;

class SupportService {
  static const String _baseUrl = kBaseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<SupportContact>> getContacts({String? propertyId}) async {
    var uri = Uri.parse('$_baseUrl/support/contacts');
    if (propertyId != null) {
      uri = uri.replace(queryParameters: {'property_id': propertyId});
    }
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list
          .map(
            (item) => SupportContact.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }
    throw Exception(
      jsonDecode(response.body)['detail'] ?? 'Failed to load contacts',
    );
  }

  Future<List<SupportMessage>> getTenantMessages() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/support/messages'),
      headers: await _headers(),
    );
    return _parseMessageList(response);
  }

  Future<SupportMessage> sendTenantMessage(
    String content, {
    String? photoUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/support/messages'),
      headers: await _headers(),
      body: jsonEncode(_messageBody(content, photoUrl)),
    );
    return _parseMessage(response);
  }

  Future<List<SupportMessage>> getManagerMessages(String tenantId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/support/tenants/$tenantId/messages'),
      headers: await _headers(),
    );
    return _parseMessageList(response);
  }

  Future<SupportMessage> sendManagerMessage(
    String tenantId,
    String content, {
    String? photoUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/support/tenants/$tenantId/messages'),
      headers: await _headers(),
      body: jsonEncode(_messageBody(content, photoUrl)),
    );
    return _parseMessage(response);
  }

  Future<String> uploadPhoto(Uint8List bytes, String filename) async {
    final token = await _authService.getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/upload'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final streamed = await request.send();
    if (streamed.statusCode == 200) {
      final body = jsonDecode(await streamed.stream.bytesToString());
      return body['url'] as String;
    }
    throw Exception('Failed to upload photo');
  }

  Map<String, String> _messageBody(String content, String? photoUrl) {
    final body = {'content': content};
    if (photoUrl != null) body['photo_url'] = photoUrl;
    return body;
  }

  List<SupportMessage> _parseMessageList(http.Response response) {
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list
          .map(
            (item) => SupportMessage.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }
    throw Exception(
      jsonDecode(response.body)['detail'] ?? 'Failed to load support messages',
    );
  }

  SupportMessage _parseMessage(http.Response response) {
    if (response.statusCode == 201 || response.statusCode == 200) {
      return SupportMessage.fromJson(jsonDecode(response.body));
    }
    throw Exception(
      jsonDecode(response.body)['detail'] ?? 'Failed to send support message',
    );
  }
}
