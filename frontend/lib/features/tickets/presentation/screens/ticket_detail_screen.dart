import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/features/tickets/data/models/ticket.dart';
import 'package:frontend/features/tickets/data/services/ticket_service.dart';
import 'package:frontend/shared/widgets/side_nav.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;

  /// 'tenant' or 'manager' — controls SideNav active item and back-nav target.
  final String role;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    this.role = 'tenant',
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final TicketService _ticketService = TicketService();
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _pendingImage;
  bool _isSending = false;
  Timer? _liveRefreshTimer;
  bool _isLiveRefreshing = false;

  Ticket? _ticket;
  List<AuditLogEntry> _auditLog = [];
  List<TicketMessage> _messages = [];
  UserInfo? _currentUser;
  bool _isLoading = true;
  String? _error;

  static const Color _navy = Color(0xFF1E293B);
  static const Color _bgGray = Color(0xFFF8FAFC);
  static const double _detailPanelHeight = 593;

  bool get _canUseOwnerControls {
    if (widget.role == 'manager') return true;
    return _ticket != null &&
        _currentUser != null &&
        _ticket!.tenantId == _currentUser!.id;
  }

  bool get _canAdvanceStatus {
    if (_ticket == null || _ticket!.isClosed) return false;
    if (widget.role == 'manager') {
      return _ticket!.status == 'opened' ||
          _ticket!.status == 'acknowledged' ||
          _ticket!.status == 'in_progress';
    }
    return _currentUser != null &&
        _ticket!.tenantId == _currentUser!.id &&
        _ticket!.status == 'resolved';
  }

  bool get _canRejectResolution {
    return widget.role == 'tenant' &&
        _ticket != null &&
        _currentUser != null &&
        _ticket!.tenantId == _currentUser!.id &&
        _ticket!.status == 'resolved';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _startLiveRefresh();
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _startLiveRefresh() {
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshLiveData();
    });
  }

  Future<void> _refreshLiveData() async {
    if (!mounted || _isLoading || _isSending || _isLiveRefreshing) return;

    _isLiveRefreshing = true;
    try {
      final results = await Future.wait([
        _ticketService.getTicket(widget.ticketId),
        _ticketService.getAuditLog(widget.ticketId),
        _ticketService.getMessages(widget.ticketId),
      ]);

      if (!mounted) return;

      setState(() {
        _ticket = results[0] as Ticket;
        _auditLog = results[1] as List<AuditLogEntry>;
        _messages = results[2] as List<TicketMessage>;
      });
    } catch (_) {
      // Silent fail for background refresh to avoid noisy UX.
    } finally {
      _isLiveRefreshing = false;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _ticketService.getTicket(widget.ticketId),
        _ticketService.getAuditLog(widget.ticketId),
        _ticketService.getMessages(widget.ticketId),
        _ticketService.getCurrentUser(),
      ]);
      setState(() {
        _ticket = results[0] as Ticket;
        _auditLog = results[1] as List<AuditLogEntry>;
        _messages = results[2] as List<TicketMessage>;
        _currentUser = results[3] as UserInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickChatImage() async {
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
        photoUrl = await _ticketService.uploadPhoto(bytes, _pendingImage!.name);
      }
      final msg = await _ticketService.sendMessage(
        widget.ticketId,
        text,
        photoUrl: photoUrl,
      );
      setState(() {
        _messages.add(msg);
        _messageController.clear();
        _pendingImage = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _advanceStatus() async {
    if (!_canAdvanceStatus || _ticket == null) return;

    try {
      await _ticketService.advanceStatus(widget.ticketId, _ticket!.nextStatus);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectResolution() async {
    if (!_canRejectResolution) return;

    final note = await _showRejectResolutionDialog();
    if (note == null) return;

    try {
      await _ticketService.rejectResolution(widget.ticketId, note: note);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showRejectResolutionDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Reject resolution',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Tell the manager what still needs attention',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Send back'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today, ${DateFormat('h:mm a').format(dt)}';
    }
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 720;
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          )
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
                'Ticket Details',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
            )
          : null,
      drawer: isPhone
          ? Drawer(
              child: SideNav(
                activeRoute: 'tickets',
                role: widget.role,
                isCompactOverride: false,
              ),
            )
          : null,
      body: isPhone
          ? content
          : Row(
              children: [
                SideNav(activeRoute: 'tickets', role: widget.role),
                Expanded(child: content),
              ],
            ),
    );
  }

  Widget _buildContent() {
    final ticket = _ticket!;
    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < 720;
    final stackPanels = width < 1180;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(40, isPhone ? 24 : 40, 40, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(ticket),
          const SizedBox(height: 24),
          if (stackPanels)
            Column(
              children: [
                _buildPropertyCard(ticket),
                const SizedBox(height: 16),
                _buildDescriptionCard(ticket),
                const SizedBox(height: 16),
                _buildMessageThread(),
                const SizedBox(height: 16),
                _buildAuditTrail(),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: Property details + Description + Attachments
                SizedBox(
                  width: 300,
                  height: _detailPanelHeight,
                  child: Column(
                    children: [
                      _buildPropertyCard(ticket),
                      const SizedBox(height: 16),
                      Expanded(child: _buildDescriptionCard(ticket)),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Center: Message thread
                Expanded(child: _buildMessageThread()),
                const SizedBox(width: 24),
                // Right: Audit trail
                SizedBox(
                  width: 281,
                  height: _detailPanelHeight,
                  child: _buildAuditTrail(),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(Ticket ticket) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TICKET #${ticket.id.substring(0, 4).toUpperCase()}',
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 760;
            final title = Text(
              ticket.title,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            );
            final actions = [
              if (!ticket.isClosed && _canUseOwnerControls) _buildEditButton(),
              if (_canRejectResolution) _buildRejectButton(),
              if (_canAdvanceStatus) _buildActionButton(ticket),
            ];

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 12, runSpacing: 12, children: actions),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: title),
                const SizedBox(width: 12),
                Wrap(spacing: 12, runSpacing: 12, children: actions),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildUrgencyBadge(ticket),
            _buildStatusBadge(ticket),
            _buildSlaBadge(ticket.slaStatus),
          ],
        ),
      ],
    );
  }

  Widget _buildEditButton() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Edit ticket coming soon')),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.edit, size: 13, color: _navy),
                const SizedBox(width: 6),
                Text(
                  'Edit Ticket',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(Ticket ticket) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _advanceStatus,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.check, size: 13, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  ticket.nextStatusActionLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRejectButton() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _rejectResolution,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.undo_outlined,
                  size: 13,
                  color: Color(0xFF991B1B),
                ),
                const SizedBox(width: 6),
                Text(
                  'Reject Resolution',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF991B1B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUrgencyBadge(Ticket ticket) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (ticket.urgency) {
      case 'urgent':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF974816);
        icon = Icons.error_outline;
        break;
      case 'normal':
        bgColor = const Color(0xFFD5E3FC);
        textColor = const Color(0xFF5B697F);
        icon = Icons.info_outline;
        break;
      default:
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        icon = Icons.arrow_downward;
    }

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            ticket.urgencyLabel,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Ticket ticket) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFD5E3FC),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, size: 12, color: Color(0xFF5B697F)),
          const SizedBox(width: 6),
          Text(
            ticket.statusLabel,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5B697F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlaBadge(String status) {
    final map = <String, List<dynamic>>{
      'On Track': [const Color(0xFFDCFCE7), const Color(0xFF166534)],
      'Approaching SLA Limit': [
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
      ],
      'SLA Breached': [const Color(0xFFFEE2E2), const Color(0xFF991B1B)],
      'Resolved Late': [const Color(0xFFFFEDD5), const Color(0xFF9A3412)],
    };
    final entry =
        map[status] ?? [const Color(0xFFF1F5F9), const Color(0xFF475569)];
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: entry[0] as Color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: entry[1] as Color),
          const SizedBox(width: 6),
          Text(
            status,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: entry[1] as Color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Property details card ───────────────────────────────────────────────────

  Widget _buildPropertyCard(Ticket ticket) {
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
          // Dark header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(
              'Property Details',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
          // Property info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.apartment, size: 22, color: _navy),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.propertyName.isNotEmpty
                                ? ticket.propertyName
                                : 'Property',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                ticket.unitNumber.isNotEmpty
                                    ? 'Unit ${ticket.unitNumber}'
                                    : 'N/A',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 22, color: _navy),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.tenantName.isNotEmpty
                                ? ticket.tenantName
                                : 'Tenant',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),
                          Text(
                            'Tenant',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Description + Attachments card ──────────────────────────────────────────

  Widget _buildDescriptionCard(Ticket ticket) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ticket Description',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ticket.description,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: Colors.black,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            _buildTimingSummary(ticket),
            const SizedBox(height: 24),
            Text(
              'Attachments (${ticket.photoUrls.length})',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
            const SizedBox(height: 8),
            if (ticket.photoUrls.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ticket.photoUrls.map((url) {
                  return GestureDetector(
                    onTap: () => _showImageDialog(url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        url,
                        width: 130,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 130,
                          height: 90,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9D9D9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  4,
                  (_) => Container(
                    width: 130,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.image,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingSummary(Ticket ticket) {
    final rows = <MapEntry<String, String?>>[
      MapEntry('Response time', ticket.responseTimeLabel),
      MapEntry('Resolution time', ticket.resolutionTimeLabel),
      MapEntry('Closure time', ticket.closureTimeLabel),
    ].where((entry) => entry.value != null).toList();

    if (rows.isEmpty && !ticket.isRecurringIssue) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Metrics',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Text(
                    entry.value!,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (ticket.isRecurringIssue && ticket.recurringIssueMessage != null)
            Text(
              ticket.recurringIssueMessage!,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                height: 1.4,
                color: const Color(0xFF92400E),
              ),
            ),
        ],
      ),
    );
  }

  // ── Message thread ──────────────────────────────────────────────────────────

  Widget _buildMessageThread() {
    return Container(
      height: _detailPanelHeight,
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
          // Header
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
                  'Message Thread',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _messages.map((m) => m.senderName).toSet().join(', '),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: _messages.isEmpty
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
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessageBubble(_messages[index]),
                  ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_pendingImage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<Uint8List>(
                            future: _pendingImage!.readAsBytes(),
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
                            onTap: () => setState(() => _pendingImage = null),
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
                      onPressed: _pickChatImage,
                      icon: const Icon(
                        Icons.attach_file,
                        color: _navy,
                        size: 20,
                      ),
                      tooltip: 'Attach image',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
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
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _navy,
                            ),
                          )
                        : IconButton(
                            onPressed: _sendMessage,
                            icon: const Icon(
                              Icons.send,
                              color: _navy,
                              size: 20,
                            ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(TicketMessage message) {
    final isMe = _currentUser != null && message.senderId == _currentUser!.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Sender name + time
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
                  'You (${_currentUser!.fullName})',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Bubble
          Container(
            constraints: const BoxConstraints(maxWidth: 290),
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
                    onTap: () => _showImageDialog(message.photoUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        message.photoUrl!,
                        width: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 200,
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
                  if (message.photoUrl != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: Text(
                        message.content,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: isMe ? Colors.white : Colors.black,
                          height: 1.5,
                        ),
                      ),
                    )
                  else
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

  void _showImageDialog(String url) {
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
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 300,
                  height: 300,
                  color: const Color(0xFFD9D9D9),
                  child: const Icon(
                    Icons.broken_image,
                    size: 48,
                    color: Colors.white54,
                  ),
                ),
              ),
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

  // ── Audit trail ─────────────────────────────────────────────────────────────

  Widget _buildAuditTrail() {
    // Show all possible statuses, mark completed ones
    final allStatuses = [
      'opened',
      'acknowledged',
      'in_progress',
      'resolved',
      'closed',
    ];
    final completedStatuses = _auditLog.map((e) => e.toStatus).toSet();
    final currentStatusIndex = allStatuses.indexOf(_ticket?.status ?? 'opened');

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 28, color: _navy),
                const SizedBox(width: 8),
                Text(
                  'Audit Trail',
                  style: GoogleFonts.roboto(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Timeline entries (reversed: newest at top)
            ...List.generate(allStatuses.length, (i) {
              final reverseIndex = allStatuses.length - 1 - i;
              final statusKey = allStatuses[reverseIndex];
              final isCompleted = completedStatuses.contains(statusKey);
              final isCurrent = reverseIndex == currentStatusIndex;
              final isLast = i == allStatuses.length - 1;

              // Find matching audit entry
              AuditLogEntry? entry;
              for (final log in _auditLog) {
                if (log.toStatus == statusKey) {
                  entry = log;
                }
              }

              return _buildAuditTimelineItem(
                statusKey: statusKey,
                entry: entry,
                isCompleted: isCompleted,
                isCurrent: isCurrent,
                isLast: isLast,
                ticket: _ticket!,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditTimelineItem({
    required String statusKey,
    required AuditLogEntry? entry,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
    required Ticket ticket,
  }) {
    final label = _statusLabel(statusKey);
    final isFuture = !isCompleted;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline dot + line
        SizedBox(
          width: 20,
          child: Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? _navy
                      : (isFuture ? Colors.white : Colors.white),
                  border: Border.all(
                    color: isFuture ? const Color(0xFFBAC7BF) : _navy,
                    width: isCurrent ? 0 : 2,
                  ),
                ),
                child: isCurrent
                    ? const Icon(Icons.circle, size: 10, color: Colors.white)
                    : isCompleted
                    ? const Icon(Icons.check, size: 12, color: _navy)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 3, color: const Color(0xFFBAC7BF)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isFuture ? Colors.black26 : Colors.black,
                  ),
                ),
                if (entry != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(entry.createdAt),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.black,
                      ),
                      children: [
                        const TextSpan(text: 'Ticket '),
                        TextSpan(
                          text: '${ticket.title} #${ticket.id.substring(0, 4)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.black,
                      ),
                      children: [
                        TextSpan(
                          text: statusKey == 'opened' ? 'opened by ' : 'by ',
                        ),
                        TextSpan(
                          text: entry.actorName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ] else if (isFuture) ...[
                  const SizedBox(height: 2),
                  if (statusKey == 'closed')
                    Text(
                      'Awaiting action from ${ticket.tenantName}',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
    return isLast ? row : IntrinsicHeight(child: row);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'opened':
        return 'Ticket Opened';
      case 'acknowledged':
        return 'Problem Acknowledged';
      case 'in_progress':
        return 'Resolving In Progress';
      case 'resolved':
        return 'Problem Resolved';
      case 'closed':
        return 'Ticket Closed';
      default:
        return status;
    }
  }
}
