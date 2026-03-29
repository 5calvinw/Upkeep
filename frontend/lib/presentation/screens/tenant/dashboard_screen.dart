import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../data/models/ticket.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/ticket_service.dart';
import '../../widgets/side_nav.dart';

class _NotificationItem {
  final String ticketId;
  final String ticketTitle;
  final String senderName;
  final String body;
  final DateTime timestamp;

  const _NotificationItem({
    required this.ticketId,
    required this.ticketTitle,
    this.senderName = '',
    required this.body,
    required this.timestamp,
  });
}

class TenantDashboardScreen extends StatefulWidget {
  const TenantDashboardScreen({super.key});

  @override
  State<TenantDashboardScreen> createState() =>
      _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends State<TenantDashboardScreen> {
  final TicketService _ticketService = TicketService();

  List<Ticket> _tickets = [];
  List<_NotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _error;
  UserInfo? _currentUser;

  static const Color _navy = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _currentUser = AuthService.currentUser.value;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final tickets = await _ticketService.listTickets();
      final activeTickets =
          tickets.where((t) => t.status != 'closed').toList();
      final userId = _currentUser?.id;
      final notifications = <_NotificationItem>[];

      // Load audit logs + messages for all active tickets in parallel
      await Future.wait(activeTickets.map((ticket) async {
        try {
          final logs = await _ticketService.getAuditLog(ticket.id);
          final messages = await _ticketService.getMessages(ticket.id);

          // Status updates performed by the manager (not the current tenant)
          for (final log in logs) {
            if (log.actorId != userId && log.toStatus != 'opened') {
              notifications.add(_NotificationItem(
                ticketId: ticket.id,
                ticketTitle: ticket.title,
                body:
                    'Status updated to ${_statusLabel(log.toStatus)}',
                timestamp: log.createdAt,
              ));
            }
          }

          // Messages sent by manager (not by the current tenant)
          for (final msg in messages) {
            if (msg.senderId != userId) {
              notifications.add(_NotificationItem(
                ticketId: ticket.id,
                ticketTitle: ticket.title,
                senderName: msg.senderName,
                body: msg.content,
                timestamp: msg.createdAt,
              ));
            }
          }
        } catch (_) {
          // Skip if details for this ticket fail to load
        }
      }));

      notifications
          .sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _tickets = tickets;
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _statusLabel(String status) {
    const labels = {
      'opened': 'Opened',
      'acknowledged': 'Acknowledged',
      'in_progress': 'In Progress',
      'resolved': 'Resolved',
      'closed': 'Closed',
    };
    return labels[status] ?? status;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String _categoryLabel(String category) {
    const labels = {
      'plumbing': 'Plumbing',
      'electrical': 'Electrical',
      'hvac': 'HVAC',
      'appliance': 'Appliance',
      'structural': 'Structural',
      'pest_control': 'Pest Control',
      'other': 'Other',
    };
    return labels[category] ?? category;
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical':
        return Icons.electrical_services;
      case 'hvac':
        return Icons.air;
      case 'appliance':
        return Icons.kitchen;
      case 'structural':
        return Icons.foundation;
      case 'pest_control':
        return Icons.bug_report;
      default:
        return Icons.build_outlined;
    }
  }

  String _shortId(Ticket t) {
    final raw = t.id.replaceAll('-', '');
    return '#${raw.substring(0, raw.length >= 4 ? 4 : raw.length).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SideNav(activeRoute: 'dashboard', role: 'tenant'),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                style:
                                    const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final resolvedTickets =
        _tickets.where((t) => t.status == 'resolved').toList();
    final activeTickets =
        _tickets.where((t) => t.status != 'closed').toList();

    // Derive unit/property info from tickets for the subtitle
    String locationText = '';
    if (_tickets.isNotEmpty) {
      final t = _tickets.first;
      final parts = [
        if (t.propertyName.isNotEmpty) t.propertyName,
        if (t.unitNumber.isNotEmpty) 'Room ${t.unitNumber}',
      ];
      locationText = parts.join(' ');
    }

    final name = _currentUser?.fullName ?? 'Tenant';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          Text(
            'Welcome back $name!',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
          if (locationText.isNotEmpty) ...[
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF64748B)),
                children: [
                  const TextSpan(
                      text: 'Welcome back, you are currently in '),
                  TextSpan(
                    text: locationText,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Action buttons
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go('/tickets/new'),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  'New Ticket',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.headset_mic_outlined, size: 16),
                label: Text(
                  'Contact Manager',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Confirmation Required + Notifications
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildConfirmationRequired(resolvedTickets),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: _buildNotifications(_notifications),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Active Tickets table
          _buildActiveTicketsTable(activeTickets),
        ],
      ),
    );
  }

  // ── Confirmation Required ─────────────────────────────────────────────────

  Widget _buildConfirmationRequired(List<Ticket> tickets) {
    return Container(
      padding: const EdgeInsets.only(left: 20, top: 20, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Confirmation Required (${tickets.length})',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _navy),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 260,
            child: tickets.isEmpty
                ? Center(
                    child: Text(
                      'No confirmations needed',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF94A3B8)),
                    ),
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Column(
                        children: tickets
                            .map((t) => _buildConfirmationItem(t))
                            .toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationItem(Ticket ticket) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              // Photo / placeholder
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ticket.photoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(ticket.photoUrl!,
                            fit: BoxFit.cover),
                      )
                    : const Icon(Icons.image_outlined,
                        color: Color(0xFF94A3B8), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            [
                              if (ticket.unitNumber.isNotEmpty)
                                'UNIT ${ticket.unitNumber}',
                              if (ticket.propertyName.isNotEmpty)
                                ticket.propertyName.toUpperCase(),
                            ].join(', '),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticket.title,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _navy),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          'Reported ',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF64748B)),
                        ),
                        Text(
                          _timeAgo(ticket.createdAt),
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _navy),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () =>
                    context.go('/tickets/${ticket.id}'),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: _navy,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: Text(
                  'View Details',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
      ],
    );
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Widget _buildNotifications(List<_NotificationItem> items) {
    return Container(
      padding: const EdgeInsets.only(left: 20, top: 20, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text(
              'Notifications',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _navy),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: items.isEmpty
                ? Center(
                    child: Text('No notifications',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF94A3B8))),
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Column(
                        children: items.map((n) => _buildNotificationItem(n)).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(_NotificationItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFCBD5E1),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMM d, h:mm a')
                      .format(item.timestamp),
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B)),
                    children: [
                      TextSpan(
                        text: item.ticketTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B)),
                      ),
                      if (item.senderName.isNotEmpty) ...[
                        const TextSpan(text: '\n'),
                        TextSpan(
                          text: item.senderName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B)),
                        ),
                        const TextSpan(text: ': '),
                      ] else
                        const TextSpan(text: '\n'),
                      TextSpan(text: item.body),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Active Tickets Table ──────────────────────────────────────────────────

  Widget _buildActiveTicketsTable(List<Ticket> tickets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Active Tickets',
          style: GoogleFonts.inter(
              fontSize: 20, fontWeight: FontWeight.w700, color: _navy),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            children: [
              // Header row
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: Color(0xFFF1F5F9), width: 1)),
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: _headerCell('Title')),
                    Expanded(
                        flex: 2,
                        child: _headerCell('Category')),
                    Expanded(
                        flex: 2, child: _headerCell('Status')),
                    Expanded(
                        flex: 2,
                        child: _headerCell('Action Required')),
                    Expanded(
                        flex: 2,
                        child: _headerCell('Actions')),
                  ],
                ),
              ),
              if (tickets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No active tickets',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF94A3B8))),
                  ),
                )
              else
                ...tickets.map((t) => _buildTableRow(t)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerCell(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF64748B)),
    );
  }

  Widget _buildTableRow(Ticket ticket) {
    final needsConfirmation = ticket.status == 'resolved';

    return InkWell(
      onTap: () => context.go('/tickets/${ticket.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
              bottom:
                  BorderSide(color: Color(0xFFF8FAFC), width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.title,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _navy),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    _timeAgo(ticket.createdAt).toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(_categoryIcon(ticket.category),
                      size: 14, color: const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(_categoryLabel(ticket.category),
                      style: GoogleFonts.inter(
                          fontSize: 13, color: _navy)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildStatusBadge(ticket.status),
              ),
            ),
            // Action Required column
            Expanded(
              flex: 2,
              child: needsConfirmation
                  ? const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444), size: 20)
                  : const SizedBox.shrink(),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      context.go('/tickets/${ticket.id}'),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: _navy,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    minimumSize: Size.zero,
                    tapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View Details',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final map = <String, List<dynamic>>{
      'opened': [
        const Color(0xFFDCFCE7),
        const Color(0xFF166534),
        'Opened'
      ],
      'acknowledged': [
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
        'Acknowledged'
      ],
      'in_progress': [
        const Color(0xFFDBEAFE),
        const Color(0xFF1D4ED8),
        'In Progress'
      ],
      'resolved': [
        const Color(0xFFF3E8FF),
        const Color(0xFF6B21A8),
        'Resolved'
      ],
      'closed': [
        const Color(0xFFF1F5F9),
        const Color(0xFF475569),
        'Closed'
      ],
    };
    final entry =
        map[status] ?? [const Color(0xFFF1F5F9), Colors.black54, status];
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: entry[0] as Color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        entry[2] as String,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: entry[1] as Color,
        ),
      ),
    );
  }
}
