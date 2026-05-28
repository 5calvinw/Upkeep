import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/features/tickets/data/models/ticket.dart';
import 'package:frontend/features/tickets/data/services/ticket_service.dart';
import 'package:frontend/shared/widgets/side_nav.dart';

class ManagerAuditLogScreen extends StatefulWidget {
  const ManagerAuditLogScreen({super.key});

  @override
  State<ManagerAuditLogScreen> createState() => _ManagerAuditLogScreenState();
}

class _ManagerAuditLogScreenState extends State<ManagerAuditLogScreen> {
  final TicketService _ticketService = TicketService();

  List<ManagerAuditLogEntry> _logs = [];
  List<Property> _properties = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedPropertyId;
  String? _selectedPropertyName;
  String _sortBy = 'date';
  bool _sortAsc = false;

  static const Color _navy = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _loadAuditLog();
  }

  Future<void> _loadAuditLog() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _ticketService.getProperties(),
        _ticketService.getManagerAuditLog(propertyId: _selectedPropertyId),
      ]);
      setState(() {
        _properties = results[0] as List<Property>;
        _logs = results[1] as List<ManagerAuditLogEntry>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onPropertyChanged(String? id, String? name) {
    setState(() {
      _selectedPropertyId = id;
      _selectedPropertyName = name;
    });
    _loadAuditLog();
  }

  List<ManagerAuditLogEntry> get _sortedLogs {
    final logs = [..._logs];
    logs.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'action':
          cmp = a.statusLabel.compareTo(b.statusLabel);
          break;
        case 'actor':
          cmp = a.actorName.toLowerCase().compareTo(b.actorName.toLowerCase());
          break;
        case 'ticket':
          cmp = a.ticketTitle.toLowerCase().compareTo(
            b.ticketTitle.toLowerCase(),
          );
          break;
        case 'unit':
          cmp = a.unitNumber.compareTo(b.unitNumber);
          break;
        case 'property':
          cmp = a.propertyName.toLowerCase().compareTo(
            b.propertyName.toLowerCase(),
          );
          break;
        case 'status':
          cmp = a.toStatus.compareTo(b.toStatus);
          break;
        case 'date':
        default:
          cmp = a.createdAt.compareTo(b.createdAt);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return logs;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month/$day/${local.year} $hour:$minute';
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
                  onPressed: _loadAuditLog,
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
                'Audit Log',
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
                activeRoute: 'audit',
                role: 'manager',
                isCompactOverride: false,
              ),
            )
          : null,
      body: isPhone
          ? content
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SideNav(activeRoute: 'audit', role: 'manager'),
                Expanded(child: content),
              ],
            ),
    );
  }

  Widget _buildContent() {
    final logs = _sortedLogs;
    final isPhone = MediaQuery.sizeOf(context).width < 720;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isPhone ? 20 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operations',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          _buildPropertyHeader(),
          const SizedBox(height: 24),
          _buildSortBar(),
          const SizedBox(height: 16),
          _buildTable(logs),
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
          (p) => PopupMenuItem<String>(
            value: p.id,
            child: Text(
              p.name,
              style: GoogleFonts.inter(fontSize: 14, color: _navy),
            ),
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              'Audit Log: $displayName',
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

  Widget _buildSortBar() {
    final isPhone = MediaQuery.sizeOf(context).width < 720;
    const sortOptions = {
      'date': 'Date',
      'action': 'Action',
      'actor': 'Actor',
      'ticket': 'Ticket',
      'unit': 'Unit',
      'property': 'Property',
      'status': 'Status',
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
                  _buildControls(sortOptions),
                  const SizedBox(width: 16),
                  _buildLogCount(),
                ],
              ),
            )
          : Row(
              children: [
                Expanded(child: _buildControls(sortOptions)),
                const SizedBox(width: 12),
                _buildLogCount(),
              ],
            ),
    );
  }

  Widget _buildControls(Map<String, String> sortOptions) {
    return Wrap(
      spacing: 10,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
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

  Widget _buildLogCount() {
    return Text(
      '${_sortedLogs.length} event${_sortedLogs.length == 1 ? '' : 's'}',
      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
    );
  }

  Widget _buildTable(List<ManagerAuditLogEntry> logs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < 980
            ? 980.0
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
                        Expanded(flex: 2, child: _headerCell('When')),
                        Expanded(flex: 2, child: _headerCell('Action')),
                        Expanded(flex: 2, child: _headerCell('Actor')),
                        Expanded(flex: 3, child: _headerCell('Ticket')),
                        Expanded(flex: 1, child: _headerCell('Unit')),
                        Expanded(flex: 2, child: _headerCell('Property')),
                        Expanded(flex: 2, child: _headerCell('Status')),
                        Expanded(flex: 2, child: _headerCell('Note')),
                      ],
                    ),
                  ),
                  if (logs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No audit events',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    )
                  else
                    ...logs.map((log) => _buildRow(log)),
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

  Widget _buildRow(ManagerAuditLogEntry log) {
    return InkWell(
      onTap: () => context.go('/manager/tickets/${log.ticketId}'),
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
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(log.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _navy,
                    ),
                  ),
                  Text(
                    _timeAgo(log.createdAt).toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(flex: 2, child: _buildAction(log)),
            Expanded(
              flex: 2,
              child: Text(
                log.actorName.isNotEmpty ? log.actorName : 'Unknown',
                style: GoogleFonts.inter(fontSize: 13, color: _navy),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                log.ticketTitle.isNotEmpty ? log.ticketTitle : 'Untitled',
                style: GoogleFonts.inter(fontSize: 13, color: _navy),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                log.unitNumber.isNotEmpty ? log.unitNumber : '-',
                style: GoogleFonts.inter(fontSize: 13, color: _navy),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                log.propertyName.isNotEmpty ? log.propertyName : '-',
                style: GoogleFonts.inter(fontSize: 13, color: _navy),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildStatusBadge(log.toStatus),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                log.note?.isNotEmpty == true ? log.note! : '-',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(ManagerAuditLogEntry log) {
    final isOpened = log.fromStatus == null && log.toStatus == 'opened';
    return Row(
      children: [
        Icon(
          isOpened ? Icons.add_circle_outline : Icons.sync_alt_outlined,
          size: 16,
          color: const Color(0xFF64748B),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isOpened ? 'New Ticket' : log.statusLabel,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _navy,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
