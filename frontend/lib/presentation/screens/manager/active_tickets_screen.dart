import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/models/ticket.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/ticket_service.dart';
import '../../widgets/side_nav.dart';

class ManagerActiveTicketsScreen extends StatefulWidget {
  const ManagerActiveTicketsScreen({super.key});

  @override
  State<ManagerActiveTicketsScreen> createState() =>
      _ManagerActiveTicketsScreenState();
}

class _ManagerActiveTicketsScreenState
    extends State<ManagerActiveTicketsScreen> {
  final TicketService _ticketService = TicketService();

  List<Ticket> _tickets = [];
  bool _isLoading = true;
  String? _error;

  // Sorting state
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
      final tickets = await _ticketService.listTickets();
      setState(() {
        _tickets = tickets.where((t) => t.status != 'closed').toList();
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
        case 'date':
        default:
          cmp = a.createdAt.compareTo(b.createdAt);
      }
      return _sortAsc ? cmp : -cmp;
    });

    return list;
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
      case 'plumbing': return Icons.plumbing;
      case 'electrical': return Icons.electrical_services;
      case 'hvac': return Icons.air;
      case 'appliance': return Icons.kitchen;
      case 'structural': return Icons.foundation;
      case 'pest_control': return Icons.bug_report;
      default: return Icons.build_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SideNav(activeRoute: 'tickets', role: 'manager'),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadTickets,
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
    final tickets = _sortedTickets;

    final managerName = AuthService.currentUser.value?.fullName ?? 'Manager';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$managerName's Properties",
            style: GoogleFonts.inter(
                fontSize: 12, color: const Color(0xFF94A3B8)),
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
          const SizedBox(height: 24),
          // Sorting / filter bar
          _buildSortBar(),
          const SizedBox(height: 16),
          // Table
          _buildTable(tickets),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
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
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Status filter
          Text('Filter:',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B))),
          const SizedBox(width: 10),
          _buildDropdown(
            value: _filterStatus,
            items: statuses,
            onChanged: (v) => setState(() => _filterStatus = v!),
          ),
          const SizedBox(width: 24),
          // Sort by
          Text('Sort by:',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B))),
          const SizedBox(width: 10),
          _buildDropdown(
            value: _sortBy,
            items: sortOptions,
            onChanged: (v) => setState(() => _sortBy = v!),
          ),
          const SizedBox(width: 10),
          // Asc / Desc toggle
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _sortAsc = !_sortAsc),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
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
                        color: _navy),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${_sortedTickets.length} ticket${_sortedTickets.length == 1 ? '' : 's'}',
            style: GoogleFonts.inter(
                fontSize: 13, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
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
      offset: const Offset(0, 36),
      itemBuilder: (context) => items.entries
          .map((e) => PopupMenuItem<String>(
                value: e.key,
                child: Text(e.value,
                    style: GoogleFonts.inter(fontSize: 13, color: _navy)),
              ))
          .toList(),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              items[value] ?? value,
              style: GoogleFonts.inter(fontSize: 13, color: _navy),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: _navy),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<Ticket> tickets) {
    return Container(
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
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: _headerCell('Title')),
                Expanded(flex: 1, child: _headerCell('Unit')),
                Expanded(flex: 2, child: _headerCell('Property')),
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
                child: Text('No active tickets',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF94A3B8))),
              ),
            )
          else
            ...tickets.map((t) => _buildRow(t)),
        ],
      ),
    );
  }

  Widget _headerCell(String label) => Text(
        label,
        style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B)),
      );

  Widget _buildRow(Ticket ticket) {
    return InkWell(
      onTap: () => context.go('/manager/tickets/${ticket.id}'),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Color(0xFFF8FAFC), width: 1)),
        ),
        child: Row(
          children: [
            // Title
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
            // Unit
            Expanded(
              flex: 1,
              child: Text(
                ticket.unitNumber.isNotEmpty ? ticket.unitNumber : '—',
                style: GoogleFonts.inter(fontSize: 13, color: _navy),
              ),
            ),
            // Property
            Expanded(
              flex: 2,
              child: Text(
                ticket.propertyName.isNotEmpty ? ticket.propertyName : '—',
                style: GoogleFonts.inter(fontSize: 13, color: _navy),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Category
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(_categoryIcon(ticket.category),
                      size: 14, color: const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(_categoryLabel(ticket.category),
                      style:
                          GoogleFonts.inter(fontSize: 13, color: _navy)),
                ],
              ),
            ),
            // Status
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildStatusBadge(ticket.status),
              ),
            ),
            // Actions
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      context.go('/manager/tickets/${ticket.id}'),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: _navy,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('View Details',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600)),
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
      'opened': [const Color(0xFFDCFCE7), const Color(0xFF166534), 'Opened'],
      'acknowledged': [const Color(0xFFFEF3C7), const Color(0xFF92400E), 'Acknowledged'],
      'in_progress': [const Color(0xFFDBEAFE), const Color(0xFF1D4ED8), 'In Progress'],
      'resolved': [const Color(0xFFF3E8FF), const Color(0xFF6B21A8), 'Resolved'],
      'closed': [const Color(0xFFF1F5F9), const Color(0xFF475569), 'Closed'],
    };
    final entry = map[status] ?? [const Color(0xFFF1F5F9), Colors.black54, status];
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
