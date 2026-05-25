import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/constants.dart';
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

  List<ManagerUnit>? _units;
  ManagerUnit? _selectedUnit;
  bool _isInviteLoading = false;
  String? _generatedToken;
  String? _inviteError;

  static const Color _navy = Color(0xFF1E293B);
  static const Color _blue = Color(0xFF3B82F6);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _red = Color(0xFFEF4444);
  static const Color _purple = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
    _loadUnits();
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

  Future<void> _loadUnits() async {
    try {
      final units = await _ticketService.getUnits();
      setState(() {
        _units = units;
        if (units.isNotEmpty && _selectedUnit == null) {
          _selectedUnit = units.first;
        }
      });
    } catch (_) {}
  }

  Future<void> _generateInvite() async {
    if (_selectedUnit == null) return;
    setState(() {
      _isInviteLoading = true;
      _inviteError = null;
      _generatedToken = null;
    });
    try {
      final token = await _ticketService.generateInvite(_selectedUnit!.id);
      setState(() {
        _generatedToken = token;
        _isInviteLoading = false;
      });
    } catch (e) {
      setState(() {
        _inviteError = e.toString();
        _isInviteLoading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                      icon: Icons.confirmation_number_outlined,
                      iconColor: _blue,
                      label: 'TOTAL TICKETS',
                      value: '${summary.totalTickets}',
                      valueColor: _blue,
                      subtext: 'All maintenance requests',
                      accentColor: _blue,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                      icon: Icons.pending_actions_outlined,
                      iconColor: _amber,
                      label: 'OPEN',
                      value: '${summary.openTickets}',
                      valueColor: _amber,
                      subtext: 'Awaiting action',
                      accentColor: _amber,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                      icon: Icons.timer_off_outlined,
                      iconColor: _red,
                      label: 'SLA BREACHES',
                      value: '${summary.slaBreachCount}',
                      valueColor: _red,
                      subtext: 'Past deadline',
                      accentColor: _red,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                      icon: Icons.repeat_outlined,
                      iconColor: _purple,
                      label: 'RECURRING',
                      value: '${summary.recurringIssueCount}',
                      valueColor: _purple,
                      subtext: 'Repeat patterns detected',
                      accentColor: _purple,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _buildInvitePanel(),
          const SizedBox(height: 24),
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
                          padding: const EdgeInsets.only(bottom: 20),
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
                  const SizedBox(width: 20),
                  Expanded(child: panels[1]),
                  const SizedBox(width: 20),
                  Expanded(child: panels[2]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInvitePanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, top: 20, bottom: 20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                const Icon(Icons.person_add_outlined,
                    color: Color(0xFF3B82F6), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Invite Tenant',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generate an invite link for a tenant to register and join a unit.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _buildUnitSelector(),
                const SizedBox(height: 12),
                _buildInviteResult(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitSelector() {
    if (_units == null || _units!.isEmpty) {
      return Row(
        children: [
          const Icon(Icons.warning_amber_outlined,
              size: 16, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Text(
            'No units available',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      );
    }

    final isPhone = MediaQuery.sizeOf(context).width < 720;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: isPhone ? double.infinity : 340,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ManagerUnit>(
                value: _selectedUnit,
                isExpanded: true,
                hint: Text(
                  'Select a unit',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                ),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _navy,
                ),
                items: _units!.map((unit) {
                  return DropdownMenuItem<ManagerUnit>(
                    value: unit,
                    child: Text(
                      '${unit.propertyName} — Unit ${unit.unitNumber}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (unit) {
                  if (unit != null) {
                    setState(() {
                      _selectedUnit = unit;
                      _generatedToken = null;
                      _inviteError = null;
                    });
                  }
                },
              ),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            onPressed: _isInviteLoading ? null : _generateInvite,
            icon: _isInviteLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.link, size: 16),
            label: Text(
              _isInviteLoading ? 'Generating...' : 'Generate Invite',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInviteResult() {
    if (_inviteError != null) {
      return Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: _red),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _inviteError!,
              style: GoogleFonts.inter(fontSize: 13, color: _red),
            ),
          ),
        ],
      );
    }

    if (_generatedToken == null) return const SizedBox.shrink();

    final inviteUrl = '$kFrontendUrl/#/register?token=$_generatedToken';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 16, color: Color(0xFF22C55E)),
              const SizedBox(width: 8),
              Text(
                'Invite generated for Unit ${_selectedUnit?.unitNumber ?? ""}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF166534),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'SHARE WITH TENANT',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Send this link to the tenant. When they open it, they will be taken to '
            'the registration page where they can create an account. '
            'They will be automatically assigned to this unit.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF475569),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(Icons.link, size: 14, color: _navy.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    inviteUrl,
                    style: GoogleFonts.inter(fontSize: 12, color: _navy),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 32,
                  child: TextButton(
                    onPressed: () => _copyToClipboard(inviteUrl, 'Link'),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'Copy Link',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _navy,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This invite expires in 7 days. The tenant must register before it expires.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    required String subtext,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: valueColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timingPanel(TicketAnalyticsSummary summary) {
    return _buildPanel(
      icon: Icons.schedule_outlined,
      iconColor: const Color(0xFF3B82F6),
      title: 'Service Timing',
      children: [
        _dataRow('Average response', summary.averageResponseTimeLabel ?? '—'),
        _dataRow(
            'Average resolution', summary.averageResolutionTimeLabel ?? '—'),
        _dataRow('Resolved tickets', '${summary.resolvedTickets}'),
        _dataRow('Closed tickets', '${summary.closedTickets}'),
      ],
    );
  }

  Widget _categoryPanel(TicketAnalyticsSummary summary) {
    final categories = summary.mostCommonCategories;
    return _buildPanel(
      icon: Icons.category_outlined,
      iconColor: const Color(0xFF8B5CF6),
      title: 'Common Categories',
      children: categories.isEmpty
          ? [_emptyText('No category data yet')]
          : categories
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(
                          _categoryIcon(item.category),
                          size: 16,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _categoryLabel(item.category),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${item.count}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
    );
  }

  Widget _recurringPanel(TicketAnalyticsSummary summary) {
    return _buildPanel(
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFF59E0B),
      title: 'Recurring Issues',
      children: summary.recurringIssues.isEmpty
          ? [_emptyText('No recurring issues detected')]
          : summary.recurringIssues
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.message,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.4,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
    );
  }

  Widget _buildPanel({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, top: 20, bottom: 20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
