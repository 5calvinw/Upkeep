import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/ticket.dart';
import '../../../data/services/ticket_service.dart';
import '../../widgets/side_nav.dart';

class NewTicketScreen extends StatefulWidget {
  const NewTicketScreen({super.key});

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final TicketService _ticketService = TicketService();

  String _selectedCategory = TicketCategory.values.first['value']!;
  XFile? _pickedImage;
  bool _isLoading = false;
  bool _isPrivate = false;
  bool _isUrgent = false;

  // Recent tickets state
  List<Ticket> _recentTickets = [];
  bool _loadingRecent = true;

  static const Color _navy = Color(0xFF283149);
  static const Color _bgGray = Color(0xFFF8FAFC);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _red = Color(0xFFD00000);
  static const Color _inputBorder = Color(0x80283149);

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
    _descriptionController.addListener(() => setState(() {}));
    _loadRecentTickets();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentTickets() async {
    try {
      final tickets = await _ticketService.listTickets();
      if (mounted) {
        setState(() {
          _recentTickets = tickets;
          _loadingRecent = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _pickedImage = file);
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      String? photoUrl;
      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();
        photoUrl = await _ticketService.uploadPhoto(bytes, _pickedImage!.name);
      }
      final ticket = await _ticketService.createTicket(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        urgency: _isUrgent ? 'urgent' : 'normal',
        photoUrl: photoUrl,
      );
      if (mounted) context.go('/tickets/${ticket.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGray,
      body: Row(
        children: [
          const SideNav(activeRoute: 'dashboard', role: 'tenant'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Page title ──
                  SizedBox(
                    width: 733,
                    child: Text(
                      'Create a New Ticket',
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height:2),
                  SizedBox(
                    width: 733,
                    child: Text(
                      'Make sure that it\'s a new problem! Check the "Tickets" tab to see if a identical ticket exists.',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Form card ──
                  _buildFormCard(),

                  const SizedBox(height: 32),

                  // ── Recent Tickets & Stats ──
                  SizedBox(
                    width: 733,
                    child: Text(
                      'Recent Tickets & Stats',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(width: 733, child: _buildStatCards()),
                  const SizedBox(height: 16),
                  _buildRecentTicketsTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form card (white rounded container) ──────────────────────────────────

  Widget _buildFormCard() {
    return Container(
      width: 733,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Title + Category
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title field (takes more space)
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabelWithCount(
                        'Title',
                        _titleController.text.length,
                        100,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 35,
                        child: TextFormField(
                          controller: _titleController,
                          maxLength: 100,
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: _inputDecoration(null).copyWith(
                            counterText: '',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Title is required'
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Category dropdown
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 35,
                        child: DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: _selectedCategory,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.black87),
                          decoration: _inputDecoration(null),
                          items: TicketCategory.values
                              .map((e) => DropdownMenuItem(
                                    value: e['value'],
                                    child: Text(e['label']!),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedCategory = v!),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Description + Supporting Pictures
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabelWithCount(
                        'Description',
                        _descriptionController.text.length,
                        300,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 175,
                        child: TextFormField(
                          controller: _descriptionController,
                          maxLength: 300,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: _inputDecoration(null).copyWith(
                            counterText: '',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Description is required'
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Supporting Pictures
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supporting Pictures (optional)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 166,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: _inputBorder),
                          ),
                          child: _pickedImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.upload_outlined,
                                        size: 28,
                                        color: Color(0xFF94A3B8)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Click to upload',
                                      style: GoogleFonts.dmSans(
                                          fontSize: 12,
                                          color: const Color(0xFF94A3B8)),
                                    ),
                                  ],
                                )
                              : Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle,
                                          size: 18,
                                          color: Color(0xFF16A34A)),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _pickedImage!.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFF16A34A),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bottom row: checkboxes + Submit
            Row(
              children: [
                // "Make my ticket private" checkbox
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _isPrivate,
                    onChanged: (v) =>
                        setState(() => _isPrivate = v ?? false),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3)),
                    activeColor: _navy,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Make my ticket private',
                  style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black),
                ),
                const SizedBox(width: 32),
                // "Urgent" checkbox
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _isUrgent,
                    onChanged: (v) =>
                        setState(() => _isUrgent = v ?? false),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3)),
                    activeColor: _navy,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Urgent',
                  style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black),
                ),
                const Spacer(),
                // Submit button
                SizedBox(
                  width: 125,
                  height: 35,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Submit',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Stat cards row ───────────────────────────────────────────────────────

  Widget _buildStatCards() {
    final totalTickets = _recentTickets.length;
    final activeTickets =
        _recentTickets.where((t) => t.status != 'closed').length;

    return Row(
      children: [
        _buildStatCard('Total Tickets:', totalTickets.toString(), '(Last 24h)'),
        const SizedBox(width: 16),
        _buildStatCard('Your Active Tickets:', activeTickets.toString(), null),
        const SizedBox(width: 16),
        _buildStatCard('Manager Last Online:', '—', null),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String? sub) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              if (sub != null) ...[
                const SizedBox(width: 4),
                Text(
                  sub,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Recent tickets table ─────────────────────────────────────────────────

  Widget _buildRecentTicketsTable() {
    return Container(
      width: 733,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF2F4F6),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Title',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Category',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                SizedBox(
                  width: 98,
                  child: Text(
                    'Actions',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table body
          if (_loadingRecent)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_recentTickets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No tickets yet.',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: Colors.black38),
                ),
              ),
            )
          else
            ...List.generate(
              _recentTickets.length > 5 ? 5 : _recentTickets.length,
              (i) => _buildTicketRow(_recentTickets[i], i),
            ),
        ],
      ),
    );
  }

  Widget _buildTicketRow(Ticket ticket, int index) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFD9D9D9),
            width: index <
                    (_recentTickets.length > 5 ? 4 : _recentTickets.length - 1)
                ? 1
                : 0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              ticket.title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(Icons.label_outline,
                    size: 13.5, color: const Color(0xFF334155)),
                const SizedBox(width: 4),
                Text(
                  _categoryLabel(ticket.category),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildStatusPill(ticket.status),
          ),
          SizedBox(
            width: 100,
            child: GestureDetector(
              onTap: () => context.go('/tickets/${ticket.id}'),
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E8EA),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  'View Details',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF191C1E),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final Map<String, List<dynamic>> map = {
      'opened': [const Color(0xFFFEF3C7), const Color(0xFF92400E), 'Pending'],
      'acknowledged': [
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
        'Pending'
      ],
      'in_progress': [
        const Color(0xFFD7E2FF),
        const Color(0xFF374765),
        'In Progress'
      ],
      'resolved': [
        const Color(0xFF6FFBBE),
        const Color(0xFF005236),
        'Resolved'
      ],
      'closed': [const Color(0xFFE2E8F0), const Color(0xFF475569), 'Closed'],
    };
    final entry = map[status] ??
        [const Color(0xFFE2E8F0), const Color(0xFF475569), status];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: entry[0] as Color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          entry[2] as String,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: entry[1] as Color,
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildFieldLabelWithCount(String label, int count, int max) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          TextSpan(
            text: '($count/$max)',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black38),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: _inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: _inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: _blue),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: _red),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  String _categoryLabel(String category) {
    final labels = {
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
}
