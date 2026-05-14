import 'package:flutter/material.dart';
import 'package:frontend/features/tickets/data/models/ticket.dart';
import 'package:frontend/features/tickets/data/services/ticket_service.dart';
import 'package:frontend/shared/widgets/side_nav.dart';
import 'package:google_fonts/google_fonts.dart';

class ManagerAnalyticsScreen extends StatefulWidget {
  const ManagerAnalyticsScreen({super.key});

  @override
  State<ManagerAnalyticsScreen> createState() => _ManagerAnalyticsScreenState();
}

class _ManagerAnalyticsScreenState extends State<ManagerAnalyticsScreen> {
  final TicketService _ticketService = TicketService();
  TicketAnalyticsSummary? _summary;
  bool _isLoading = true;
  String? _error;

  static const Color _navy = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final summary = await _ticketService.getManagerAnalytics();
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
                  onPressed: _loadAnalytics,
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        : _buildContent(_summary!);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: isPhone
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: const IconThemeData(color: _navy),
              title: Text(
                'Analytics',
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
                activeRoute: 'analytics',
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
                const SideNav(activeRoute: 'analytics', role: 'manager'),
                Expanded(child: content),
              ],
            ),
    );
  }

  Widget _buildContent(TicketAnalyticsSummary summary) {
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
          Text(
            'Maintenance Analytics',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 720
                  ? 1
                  : constraints.maxWidth < 1100
                  ? 2
                  : 4;
              final cardWidth =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _metricCard(
                    cardWidth,
                    'TOTAL TICKETS',
                    '${summary.totalTickets}',
                    Icons.confirmation_number_outlined,
                  ),
                  _metricCard(
                    cardWidth,
                    'OPEN',
                    '${summary.openTickets}',
                    Icons.pending_actions_outlined,
                  ),
                  _metricCard(
                    cardWidth,
                    'SLA BREACHES',
                    '${summary.slaBreachCount}',
                    Icons.timer_off_outlined,
                  ),
                  _metricCard(
                    cardWidth,
                    'RECURRING',
                    '${summary.recurringIssueCount}',
                    Icons.repeat_outlined,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 980;
              final panels = [
                _timingPanel(summary),
                _categoryPanel(summary),
                _recurringPanel(summary),
              ];
              if (stack) {
                return Column(
                  children: panels
                      .map(
                        (panel) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: panel,
                        ),
                      )
                      .toList(),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: panels[0]),
                  const SizedBox(width: 16),
                  Expanded(child: panels[1]),
                  const SizedBox(width: 16),
                  Expanded(child: panels[2]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _metricCard(double width, String label, String value, IconData icon) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: _navy),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _timingPanel(TicketAnalyticsSummary summary) {
    return _panel('Service timing', [
      _dataRow('Average response', summary.averageResponseTimeLabel ?? '—'),
      _dataRow('Average resolution', summary.averageResolutionTimeLabel ?? '—'),
      _dataRow('Resolved tickets', '${summary.resolvedTickets}'),
      _dataRow('Closed tickets', '${summary.closedTickets}'),
    ]);
  }

  Widget _categoryPanel(TicketAnalyticsSummary summary) {
    final categories = summary.mostCommonCategories;
    if (categories.isEmpty) {
      return _panel('Common categories', [_emptyText('No category data yet')]);
    }
    return _panel(
      'Common categories',
      categories
          .map(
            (item) => _dataRow(_categoryLabel(item.category), '${item.count}'),
          )
          .toList(),
    );
  }

  Widget _recurringPanel(TicketAnalyticsSummary summary) {
    if (summary.recurringIssues.isEmpty) {
      return _panel('Recurring issues', [
        _emptyText('No recurring issues detected'),
      ]);
    }
    return _panel(
      'Recurring issues',
      summary.recurringIssues
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                item.message,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyText(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
    );
  }
}
