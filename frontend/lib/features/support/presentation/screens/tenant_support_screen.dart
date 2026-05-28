import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:frontend/features/auth/data/auth_service.dart';
import 'package:frontend/features/support/data/support_models.dart';
import 'package:frontend/features/support/data/support_service.dart';
import 'package:frontend/features/tickets/data/models/ticket.dart';
import 'package:frontend/shared/widgets/side_nav.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class TenantSupportScreen extends StatefulWidget {
  const TenantSupportScreen({super.key});

  @override
  State<TenantSupportScreen> createState() => _TenantSupportScreenState();
}

class _TenantSupportScreenState extends State<TenantSupportScreen> {
  final SupportService _supportService = SupportService();
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  List<SupportMessage> _messages = [];
  UserInfo? _currentUser;
  XFile? _pendingImage;
  Timer? _refreshTimer;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isRefreshing = false;
  String? _error;

  static const Color _navy = Color(0xFF1E293B);
  static const Color _bgGray = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshMessages();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_supportService.getTenantMessages()]);
      if (!mounted) return;
      setState(() {
        _messages = results[0];
        _currentUser = AuthService.currentUser.value;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshMessages() async {
    if (!mounted || _isLoading || _isSending || _isRefreshing) return;
    _isRefreshing = true;
    try {
      final messages = await _supportService.getTenantMessages();
      if (mounted) setState(() => _messages = messages);
    } catch (_) {
      // Background refresh should not interrupt typing.
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _pickImage() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _pendingImage = file);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingImage == null) return;

    setState(() => _isSending = true);
    try {
      String? photoUrl;
      if (_pendingImage != null) {
        final bytes = await _pendingImage!.readAsBytes();
        photoUrl = await _supportService.uploadPhoto(
          bytes,
          _pendingImage!.name,
        );
      }
      final message = await _supportService.sendTenantMessage(
        text,
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(message);
        _messageController.clear();
        _pendingImage = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 720;
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _buildError()
        : _buildContent();

    return Scaffold(
      backgroundColor: _bgGray,
      appBar: isPhone
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: const IconThemeData(color: _navy),
              title: Text(
                'Support',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
            )
          : null,
      drawer: isPhone
          ? const Drawer(
              child: SideNav(
                activeRoute: 'support',
                role: 'tenant',
                isCompactOverride: false,
              ),
            )
          : null,
      body: isPhone
          ? content
          : Row(
              children: [
                const SideNav(activeRoute: 'support', role: 'tenant'),
                Expanded(child: content),
              ],
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final isPhone = MediaQuery.sizeOf(context).width < 720;
    return Padding(
      padding: EdgeInsets.all(isPhone ? 20 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUPPORT',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Property Support',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SupportChatPanel(
              title: 'Message Thread',
              subtitle: 'Your conversation with property management',
              messages: _messages,
              currentUser: _currentUser,
              controller: _messageController,
              pendingImage: _pendingImage,
              isSending: _isSending,
              onPickImage: _pickImage,
              onClearImage: () => setState(() => _pendingImage = null),
              onSend: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class SupportChatPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<SupportMessage> messages;
  final UserInfo? currentUser;
  final TextEditingController controller;
  final XFile? pendingImage;
  final bool isSending;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final VoidCallback onSend;

  const SupportChatPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.messages,
    required this.currentUser,
    required this.controller,
    required this.pendingImage,
    required this.isSending,
    required this.onPickImage,
    required this.onClearImage,
    required this.onSend,
  });

  static const Color _navy = Color(0xFF1E293B);

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today, ${DateFormat('h:mm a').format(dt)}';
    }
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFE2E8F0),
                  blurRadius: 1,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.black38,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessageBubble(context, messages[index]),
                  ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pendingImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: FutureBuilder<Uint8List>(
                      future: pendingImage!.readAsBytes(),
                      builder: (ctx, snap) {
                        if (!snap.hasData) {
                          return Container(
                            width: 64,
                            height: 64,
                            color: const Color(0xFFD9D9D9),
                          );
                        }
                        return Image.memory(
                          snap.data!,
                          height: 64,
                          width: 64,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: onClearImage,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                onPressed: onPickImage,
                icon: const Icon(Icons.attach_file, color: _navy, size: 20),
                tooltip: 'Attach image',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: GoogleFonts.dmSans(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: Colors.black38,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _navy,
                      ),
                    )
                  : IconButton(
                      onPressed: onSend,
                      icon: const Icon(Icons.send, color: _navy, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, SupportMessage message) {
    final isMe = currentUser != null && message.senderId == currentUser!.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isMe)
                Text(
                  message.senderName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
              if (!isMe) const SizedBox(width: 8),
              Text(
                _formatDate(message.createdAt),
                style: GoogleFonts.dmSans(fontSize: 11, color: Colors.black54),
              ),
              if (isMe) const SizedBox(width: 8),
              if (isMe)
                Text(
                  'You',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: message.photoUrl != null && message.content.isEmpty
                ? EdgeInsets.zero
                : const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: message.photoUrl != null && message.content.isEmpty
                  ? Colors.transparent
                  : (isMe ? _navy : Colors.white),
              borderRadius: BorderRadius.only(
                topRight: const Radius.circular(10),
                bottomLeft: const Radius.circular(10),
                bottomRight: const Radius.circular(10),
                topLeft: isMe ? const Radius.circular(10) : Radius.zero,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.photoUrl != null)
                  GestureDetector(
                    onTap: () => _showImageDialog(context, message.photoUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        message.photoUrl!,
                        width: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 220,
                          height: 120,
                          color: const Color(0xFFD9D9D9),
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (message.content.isNotEmpty) ...[
                  if (message.photoUrl != null) const SizedBox(height: 6),
                  Text(
                    message.content,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: isMe ? Colors.white : Colors.black,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImageDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: -12,
              right: -12,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
