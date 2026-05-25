import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/auth/data/auth_service.dart';
import 'package:frontend/features/tickets/data/models/ticket.dart';
import 'package:frontend/features/tickets/data/services/ticket_service.dart';
import 'package:frontend/shared/widgets/side_nav.dart';
import 'package:google_fonts/google_fonts.dart';

class TenantActiveTicketsScreen extends StatefulWidget {
  const TenantActiveTicketsScreen({super.key});

  @override
  State<TenantActiveTicketsScreen> createState() =>
      _TenantActiveTicketsScreenState();
}

class _TenantActiveTicketsScreenState extends State<TenantActiveTicketsScreen> {
  final TicketService _ticketService = TicketService();

  List<Ticket> _tickets = [];
  bool _isLoading = true;
  String? _error;
  String _sortBy = 'date';
  bool _sortAsc = false;
  String _filterStatus = 'all';

  static const Color _navy = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tickets = await _ticketService.listActiveTickets();
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Ticket> get _sortedTickets {
    var list = [..._tickets];

    if (_filterStatus != 'all') {
      list = list.where((t) => t.status == _filterStatus).toList();
    }

    list.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'title':
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'status':
          cmp = a.status.compareTo(b.status);
          break;
        case 'category':
          cmp = a.category.compareTo(b.category);
          break;
        case 'visibility':
          cmp = _isOwnTicket(
            a,
          ).toString().compareTo(_isOwnTicket(b).toString());
          break;
        case 'date':
        default:
          cmp = a.createdAt.compareTo(b.createdAt);
      }
      return _sortAsc ? cmp : -cmp;
    });

    return list;
  }

  bool _isOwnTicket(Ticket ticket) {
    return AuthService.currentUser.value?.id == ticket.tenantId;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String _categoryLabel(String c) {
    const labels = {
      'plumbing': 'Plumbing',
      'electrical': 'Electrical',
      'hvac': 'HVAC',
      'appliance': 'Appliance',
      'structural': 'Structural',
      'pest_control': 'Pest Control',
      'other': 'Other',
    };
    return labels[c] ?? c;
  }

  IconData _categoryIcon(String c) {
    switch (c) {
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

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 720;
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadTickets,
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        : _buildContent();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: isPhone
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: const IconThemeData(color: _navy),
              title: Text(
                'Active Tickets',
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
                activeRoute: 'tickets',
                role: 'tenant',
                isCompactOverride: false,
              ),
            )
          : null,
      body: isPhone
          ? content
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SideNav(activeRoute: 'tickets', role: 'tenant'),
                Expanded(child: content),
              ],
            ),
    );
  }

  Widget _buildContent() {
    final tickets = _sortedTickets;
    final name = AuthService.currentUser.value?.fullName ?? 'Tenant';
    final isPhone = MediaQuery.sizeOf(context).width < 720;
    String? propertyName;
    for (final ticket in _tickets) {
      if (ticket.propertyName.isNotEmpty) {
        propertyName = ticket.propertyName;
        break;
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isPhone ? 20 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            propertyName ?? '$name\'s property',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Active Tickets',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track your tickets and non-private tickets shared by neighbors in the same property.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          _buildSortBar(),
          const SizedBox(height: 16),
          _buildTable(tickets),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    final isPhone = MediaQuery.sizeOf(context).width < 720;
    const statuses = {
      'all': 'All Statuses',
      'opened': 'Opened',
      'acknowledged': 'Acknowledged',
      'in_progress': 'In Progress',
      'resolved': 'Resolved',
    };
    const sortOptions = {
      'date': 'Date',
      'title': 'Title',
      'status': 'Status',
      'category': 'Category',
      'visibility': 'Visibility',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isPhone
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildControlsGroup(statuses, sortOptions),
                  const SizedBox(width: 16),
                  _buildTicketCount(),
                ],
              ),
            )
          : Row(
              children: [
                Expanded(child: _buildControlsGroup(statuses, sortOptions)),
                const SizedBox(width: 12),
                _buildTicketCount(),
              ],
            ),
    );
  }

  Widget _buildControlsGroup(
    Map<String, String> statuses,
    Map<String, String> sortOptions,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Filter:',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        _buildDropdown(
          value: _filterStatus,
          items: statuses,
          onChanged: (v) => setState(() => _filterStatus = v!),
        ),
        Text(
          'Sort by:',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        _buildDropdown(
          value: _sortBy,
          items: sortOptions,
          onChanged: (v) => setState(() => _sortBy = v!),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _sortAsc = !_sortAsc),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: _navy,
                ),
                const SizedBox(width: 4),
                Text(
                  _sortAsc ? 'Asc' : 'Desc',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCount() {
    return Text(
      '${_sortedTickets.length} ticket${_sortedTickets.length == 1 ? '' : 's'}',
      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
    );
  }

  Widget _buildDropdown({
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      offset: const Offset(0, 4),
      itemBuilder: (context) => items.entries
          .map(
            (e) => PopupMenuItem<String>(
              value: e.key,
              child: Text(
                e.value,
                style: GoogleFonts.inter(fontSize: 13, color: _navy),
              ),
            ),
          )
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            items[value] ?? value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _navy,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 16, color: _navy),
        ],
      ),
    );
  }

  Widget _buildTable(List<Ticket> tickets) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < 900
            ? 900.0
            : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: _headerCell('Title')),
                        Expanded(flex: 1, child: _headerCell('Unit')),
                        Expanded(flex: 2, child: _headerCell('Visibility')),
                        Expanded(flex: 2, child: _headerCell('Category')),
                        Expanded(flex: 2, child: _headerCell('Status')),
                        Expanded(flex: 2, child: _headerCell('Actions')),
                      ],
                    ),
                  ),
                  if (tickets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No active tickets',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    )
                  else
                    ...tickets.map((t) => _buildRow(t)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _headerCell(String label) => Text(
    label,
    style: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF64748B),
    ),
  );

  Widget _buildRow(Ticket ticket) {
    return InkWell(
      onTap: () => context.go('/tickets/${ticket.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF8FAFC), width: 1),
          ),
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
                      color: _navy,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    _timeAgo(ticket.createdAt).toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                ticket.unitNumber.isNotEmpty ? ticket.unitNumber : '-',
                style: GoogleFonts.inter(fontSize: 13, color: _navy),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildVisibilityBadge(ticket),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(
                    _categoryIcon(ticket.category),
                    size: 14,
                    color: const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _categoryLabel(ticket.category),
                      style: GoogleFonts.inter(fontSize: 13, color: _navy),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.go('/tickets/${ticket.id}'),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: _navy,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View Details',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityBadge(Ticket ticket) {
    final isOwn = _isOwnTicket(ticket);
    final label = isOwn ? 'Your ticket' : 'Shared';
    final bg = isOwn ? const Color(0xFFE0F2FE) : const Color(0xFFDCFCE7);
    final fg = isOwn ? const Color(0xFF075985) : const Color(0xFF166534);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final map = <String, List<dynamic>>{
      'opened': [const Color(0xFFDCFCE7), const Color(0xFF166534), 'Opened'],
      'acknowledged': [
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
        'Acknowledged',
      ],
      'in_progress': [
        const Color(0xFFDBEAFE),
        const Color(0xFF1D4ED8),
        'In Progress',
      ],
      'resolved': [
        const Color(0xFFF3E8FF),
        const Color(0xFF6B21A8),
        'Resolved',
      ],
      'closed': [const Color(0xFFF1F5F9), const Color(0xFF475569), 'Closed'],
    };
    final entry =
        map[status] ?? [const Color(0xFFF1F5F9), Colors.black54, status];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
