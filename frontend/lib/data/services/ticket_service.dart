import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/ticket.dart';
import 'auth_service.dart';
import '../../core/constants.dart';

class TicketService {
  static const String _baseUrl = kBaseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Ticket> getTicket(String ticketId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/tickets/$ticketId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return Ticket.fromJson(jsonDecode(response.body));
    }
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to load ticket');
  }

  Future<List<AuditLogEntry>> getAuditLog(String ticketId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/tickets/$ticketId/audit'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((e) => AuditLogEntry.fromJson(e)).toList();
    }
    throw Exception('Failed to load audit log');
  }

  Future<List<TicketMessage>> getMessages(String ticketId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/tickets/$ticketId/messages'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((e) => TicketMessage.fromJson(e)).toList();
    }
    throw Exception('Failed to load messages');
  }

  Future<TicketMessage> sendMessage(String ticketId, String content, {String? photoUrl}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/tickets/$ticketId/messages'),
      headers: await _headers(),
      body: jsonEncode({
        'content': content,
        if (photoUrl != null) 'photo_url': photoUrl,
      }),
    );
    if (response.statusCode == 201) {
      return TicketMessage.fromJson(jsonDecode(response.body));
    }
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to send message');
  }

  Future<Ticket> advanceStatus(String ticketId, String newStatus, {String? note}) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/tickets/$ticketId/status'),
      headers: await _headers(),
      body: jsonEncode({
        'status': newStatus,
        if (note != null) 'note': note, // ignore: use_null_aware_elements
      }),
    );
    if (response.statusCode == 200) {
      return Ticket.fromJson(jsonDecode(response.body));
    }
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to update status');
  }

  Future<UserInfo> getCurrentUser() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/me'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return UserInfo.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load user');
  }

  Future<List<Ticket>> listTickets() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/tickets'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((e) => Ticket.fromJson(e)).toList();
    }
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to load tickets');
  }

  Future<String> uploadPhoto(Uint8List bytes, String filename) async {
    final token = await _authService.getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/upload'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await request.send();
    if (streamed.statusCode == 200) {
      final body = jsonDecode(await streamed.stream.bytesToString());
      return body['url'] as String;
    }
    throw Exception('Failed to upload photo');
  }

  Future<Ticket> createTicket({
    required String title,
    required String description,
    required String category,
    required String urgency,
    String? photoUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/tickets'),
      headers: await _headers(),
      body: jsonEncode({
        'title': title,
        'description': description,
        'category': category,
        'urgency': urgency,
        'photo_url': photoUrl,
      }),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return Ticket.fromJson(jsonDecode(response.body));
    }
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to create ticket');
  }
}
