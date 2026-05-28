import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/features/auth/data/auth_service.dart';
import 'package:frontend/features/support/data/support_models.dart';
import 'package:frontend/features/support/data/support_service.dart';
import 'package:frontend/features/support/presentation/screens/tenant_support_screen.dart';
import 'package:frontend/features/tickets/data/models/ticket.dart';
import 'package:frontend/features/tickets/data/services/ticket_service.dart';
import 'package:frontend/shared/widgets/side_nav.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ManagerSupportScreen extends StatefulWidget {
  const ManagerSupportScreen({super.key});

  @override
  State<ManagerSupportScreen> createState() => _ManagerSupportScreenState();
}

class _ManagerSupportScreenState extends State<ManagerSupportScreen> {
  final SupportService _supportService = SupportService();
  final TicketService _ticketService = TicketService();
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  List<Property> _properties = [];
  List<SupportContact> _contacts = [];
  List<SupportMessage> _messages = [];
  UserInfo? _currentUser;
  SupportContact? _selectedContact;
  String? _selectedPropertyId;
  String? _selectedPropertyName;
  XFile? _pendingImage;
  Timer? _refreshTimer;
  bool _isLoading = true;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  bool _isRefreshing = false;
  String? _error;

  static const Color _navy = Color(0xFF1E293B);
  static const Color _bgGray = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _currentUser = AuthService.currentUser.value;
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshSelectedThread();
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
      final results = await Future.wait([
        _ticketService.getProperties(),
        _supportService.getContacts(propertyId: _selectedPropertyId),
      ]);
      final properties = results[0] as List<Property>;
      final contacts = results[1] as List<SupportContact>;
      if (!mounted) return;

      final selected =
          contacts.any(
            (contact) => contact.tenantId == _selectedContact?.tenantId,
          )
          ? contacts.firstWhere(
              (contact) => contact.tenantId == _selectedContact!.tenantId,
            )
          : (contacts.isNotEmpty ? contacts.first : null);

      setState(() {
        _properties = properties;
        _contacts = contacts;
        _selectedContact = selected;
        _isLoading = false;
      });
      if (selected != null) await _loadMessages(selected);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMessages(SupportContact contact) async {
    setState(() {
      _selectedContact = contact;
      _isLoadingMessages = true;
      _pendingImage = null;
      _messageController.clear();
    });
    try {
      final messages = await _supportService.getManagerMessages(
        contact.tenantId,
      );
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoadingMessages = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMessages = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _refreshSelectedThread() async {
    final contact = _selectedContact;
    if (!mounted ||
        _isLoading ||
        _isSending ||
        _isRefreshing ||
        contact == null) {
      return;
    }
    _isRefreshing = true;
    try {
      final results = await Future.wait([
        _supportService.getContacts(propertyId: _selectedPropertyId),
        _supportService.getManagerMessages(contact.tenantId),
      ]);
      if (!mounted) return;
      final contacts = results[0] as List<SupportContact>;
      setState(() {
        _contacts = contacts;
        _messages = results[1] as List<SupportMessage>;
        _selectedContact = contacts
            .where((item) => item.tenantId == contact.tenantId)
            .firstOrNull;
      });
    } catch (_) {
      // Keep background refresh quiet.
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _pickImage() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _pendingImage = file);
  }

  Future<void> _sendMessage() async {
    final contact = _selectedContact;
    final text = _messageController.text.trim();
    if (contact == null || (text.isEmpty && _pendingImage == null)) return;

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
      final message = await _supportService.sendManagerMessage(
        contact.tenantId,
        text,
        photoUrl: photoUrl,
      );
      final contacts = await _supportService.getContacts(
        propertyId: _selectedPropertyId,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(message);
        _contacts = contacts;
        _selectedContact = contacts
            .where((item) => item.tenantId == contact.tenantId)
            .firstOrNull;
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

  void _onPropertyChanged(String? id, String? name) {
    setState(() {
      _selectedPropertyId = id;
      _selectedPropertyName = name;
      _selectedContact = null;
      _messages = [];
    });
    _loadData();
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
                role: 'manager',
                isCompactOverride: false,
              ),
            )
          : null,
      body: isPhone
          ? content
          : Row(
              children: [
                const SideNav(activeRoute: 'support', role: 'manager'),
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
    final selected = _selectedContact;
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
          _buildPropertyHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: isPhone
                ? Column(
                    children: [
                      SizedBox(height: 260, child: _buildContactList()),
                      const SizedBox(height: 16),
                      Expanded(child: _buildThread(selected)),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 340, child: _buildContactList()),
                      const SizedBox(width: 20),
                      Expanded(child: _buildThread(selected)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyHeader() {
    final displayName = _selectedPropertyName ?? 'All Properties';
    return PopupMenuButton<String>(
      offset: const Offset(0, 6),
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == '__all__') {
          _onPropertyChanged(null, null);
        } else {
          final prop = _properties.firstWhere((p) => p.id == value);
          _onPropertyChanged(prop.id, prop.name);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: '__all__',
          child: Text(
            'All Properties',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _navy,
            ),
          ),
        ),
        ..._properties.map(
          (property) => PopupMenuItem<String>(
            value: property.id,
            child: Text(
              property.name,
              style: GoogleFonts.inter(fontSize: 14, color: _navy),
            ),
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              'Support: $displayName',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down, size: 24, color: _navy),
        ],
      ),
    );
  }

  Widget _buildContactList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(
                  'Contacts',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_contacts.length}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: _contacts.isEmpty
                ? Center(
                    child: Text(
                      'No tenants found',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.black38,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _contacts.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      final isSelected =
                          contact.tenantId == _selectedContact?.tenantId;
                      return _buildContactTile(contact, isSelected);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(SupportContact contact, bool isSelected) {
    return Material(
      color: isSelected ? const Color(0xFFF1F5F9) : Colors.white,
      child: InkWell(
        onTap: () => _loadMessages(contact),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _navy,
                child: Text(
                  contact.tenantName.isEmpty
                      ? '?'
                      : contact.tenantName.substring(0, 1).toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contact.tenantName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (contact.lastMessageAt != null)
                          Text(
                            _timeAgo(contact.lastMessageAt!),
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${contact.propertyName} • Unit ${contact.unitNumber}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      contact.lastMessage.isEmpty
                          ? contact.tenantEmail
                          : contact.lastMessage,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThread(SupportContact? selected) {
    if (selected == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Select a tenant',
            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.black45),
          ),
        ),
      );
    }

    if (_isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    return SupportChatPanel(
      title: selected.tenantName,
      subtitle: '${selected.propertyName} • Unit ${selected.unitNumber}',
      messages: _messages,
      currentUser: _currentUser,
      controller: _messageController,
      pendingImage: _pendingImage,
      isSending: _isSending,
      onPickImage: _pickImage,
      onClearImage: () => setState(() => _pendingImage = null),
      onSend: _sendMessage,
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return DateFormat('MMM d').format(dt);
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Now';
  }
}
