import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/tickets/data/models/ticket.dart';
import 'package:frontend/features/tickets/data/services/ticket_service.dart';
import 'package:frontend/shared/widgets/side_nav.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

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
  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey _categoryFieldKey = GlobalKey();
  static const int _maxAttachments = 4;

  String _selectedCategory = TicketCategory.values.first['value']!;
  List<XFile?> _pickedImages = [];
  bool _isLoading = false;
  bool _isPrivate = false;
  bool _isUrgent = false;

  // Recent tickets state
  List<Ticket> _recentTickets = [];
  bool _loadingRecent = true;

  static const Color _navy = Color(0xFF1E293B);
  static const Color _bgGray = Color(0xFFF8FAFC);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _red = Color(0xFFD00000);
  static const Color _inputBorder = Color(0xFFCBD5E1);
  static const double _contentWidth = 920;

  bool _isPhone(BuildContext context) => MediaQuery.sizeOf(context).width < 720;

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
    if (_selectedImages.length >= _maxAttachments) return;

    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _pickedImages = [..._selectedImages, file]);
    }
  }

  void _removeImage(int index) {
    final nextImages = [..._selectedImages]..removeAt(index);
    setState(() => _pickedImages = nextImages);
  }

  List<XFile> get _selectedImages =>
      _pickedImages.whereType<XFile>().toList(growable: false);

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final uploadedUrls = <String>[];
      for (final image in _selectedImages) {
        final bytes = await image.readAsBytes();
        final photoUrl = await _ticketService.uploadPhoto(bytes, image.name);
        uploadedUrls.add(photoUrl);
      }
      final ticket = await _ticketService.createTicket(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        urgency: _isUrgent ? 'urgent' : 'normal',
        photoUrls: uploadedUrls,
      );
      if (mounted) context.go('/tickets/${ticket.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = _isPhone(context);
    final content = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isPhone ? 20 : 40,
        isPhone ? 24 : 40,
        isPhone ? 20 : 40,
        48,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page title ──
              SizedBox(
                width: double.infinity,
                child: Text(
                  'Create a New Ticket',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: Text(
                  'Make sure that it\'s a new problem! Check the "Tickets" tab to see if a identical ticket exists.',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Form card ──
              _buildFormCard(),

              const SizedBox(height: 32),

              // ── Recent Tickets & Stats ──
              SizedBox(
                width: double.infinity,
                child: Text(
                  'Recent Tickets & Stats',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildStatCards(),
              const SizedBox(height: 16),
              _buildRecentTicketsTable(),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: _bgGray,
      appBar: isPhone
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: const IconThemeData(color: _navy),
              title: Text(
                'New Ticket',
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
                activeRoute: 'dashboard',
                role: 'tenant',
                isCompactOverride: false,
              ),
            )
          : null,
      body: isPhone
          ? content
          : Row(
              children: [
                const SideNav(activeRoute: 'dashboard', role: 'tenant'),
                Expanded(child: content),
              ],
            ),
    );
  }

  // ── Form card (white rounded container) ──────────────────────────────────

  Widget _buildFormCard() {
    final isPhone = _isPhone(context);
    return Container(
      width: double.infinity,
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Title + Category
            if (isPhone)
              Column(
                children: [
                  _buildTitleField(),
                  const SizedBox(height: 16),
                  _buildCategoryField(),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildTitleField()),
                  const SizedBox(width: 24),
                  Expanded(flex: 3, child: _buildCategoryField()),
                ],
              ),
            const SizedBox(height: 12),

            // Row 2: Description + Supporting Pictures
            if (isPhone)
              Column(
                children: [
                  _buildDescriptionField(),
                  const SizedBox(height: 16),
                  _buildSupportingPicturesField(),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildDescriptionField()),
                  const SizedBox(width: 24),
                  Expanded(flex: 3, child: _buildSupportingPicturesField()),
                ],
              ),
            const SizedBox(height: 16),

            // Bottom row: checkboxes + Submit
            if (isPhone)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 20,
                    runSpacing: 10,
                    children: [
                      _buildCheckboxWithLabel(
                        value: _isPrivate,
                        onChanged: (v) => setState(() => _isPrivate = v ?? false),
                        label: 'Make my ticket private',
                      ),
                      _buildCheckboxWithLabel(
                        value: _isUrgent,
                        onChanged: (v) => setState(() => _isUrgent = v ?? false),
                        label: 'Urgent',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: _buildSubmitButton()),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 10,
                      children: [
                        _buildCheckboxWithLabel(
                          value: _isPrivate,
                          onChanged: (v) => setState(() => _isPrivate = v ?? false),
                          label: 'Make my ticket private',
                        ),
                        _buildCheckboxWithLabel(
                          value: _isUrgent,
                          onChanged: (v) => setState(() => _isUrgent = v ?? false),
                          label: 'Urgent',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildSubmitButton(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxWithLabel({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            activeColor: _navy,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black)),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: 132,
      height: 40,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                'Submit',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
              ),
      ),
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabelWithCount('Title', _titleController.text.length, 100),
        const SizedBox(height: 4),
        SizedBox(
          height: 35,
          child: TextFormField(
            controller: _titleController,
            maxLength: 100,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: _inputDecoration(null).copyWith(counterText: ''),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Title is required' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _navy,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 35,
          child: InkWell(
            key: _categoryFieldKey,
            onTap: _openCategoryMenu,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: _inputDecoration(null).copyWith(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedCategoryLabel(),
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCategoryMenu() async {
    final ctx = _categoryFieldKey.currentContext;
    if (ctx == null) return;

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + size.width,
        offset.dy,
      ),
      items: TicketCategory.values
          .map(
            (e) => PopupMenuItem<String>(
              value: e['value'],
              child: Text(
                e['label']!,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
              ),
            ),
          )
          .toList(growable: false),
    );

    if (picked != null && mounted) {
      setState(() => _selectedCategory = picked);
    }
  }

  String _selectedCategoryLabel() {
    for (final category in TicketCategory.values) {
      if (category['value'] == _selectedCategory) {
        return category['label']!;
      }
    }
    return _selectedCategory;
  }

  Widget _buildDescriptionField() {
    return Column(
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
            decoration: _inputDecoration(null).copyWith(counterText: ''),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Description is required'
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSupportingPicturesField() {
    return Column(
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
        _buildAttachmentsPanel(),
      ],
    );
  }

  // ── Stat cards row ───────────────────────────────────────────────────────

  Widget _buildStatCards() {
    final totalTickets = _recentTickets.length;
    final activeTickets = _recentTickets
        .where((t) => t.status != 'closed')
        .length;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard('Total Tickets:', totalTickets.toString(), '(Last 24h)'),
        _buildStatCard('Your Active Tickets:', activeTickets.toString(), null),
        _buildStatCard('Manager Last Online:', '—', null),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String? sub) {
    return Container(
      width: 200,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _navy,
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
                  color: _navy,
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
      width: double.infinity,
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
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = constraints.maxWidth < 720
                  ? 720.0
                  : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFFF1F5F9),
                              width: 1,
                            ),
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
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
                                fontSize: 13,
                                color: Colors.black38,
                              ),
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
                ),
              );
            },
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
            color: const Color(0xFFF1F5F9),
            width:
                index <
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
                Icon(
                  Icons.label_outline,
                  size: 13.5,
                  color: const Color(0xFF334155),
                ),
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
          Expanded(flex: 2, child: _buildStatusPill(ticket.status)),
          SizedBox(
            width: 100,
            child: GestureDetector(
              onTap: () => context.go('/tickets/${ticket.id}'),
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  'View Details',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _navy,
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
        'Pending',
      ],
      'in_progress': [
        const Color(0xFFD7E2FF),
        const Color(0xFF374765),
        'In Progress',
      ],
      'resolved': [
        const Color(0xFF6FFBBE),
        const Color(0xFF005236),
        'Resolved',
      ],
      'closed': [const Color(0xFFE2E8F0), const Color(0xFF475569), 'Closed'],
    };
    final entry =
        map[status] ??
        [const Color(0xFFE2E8F0), const Color(0xFF475569), status];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
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

  Widget _buildAttachmentsPanel() {
    final selectedImages = _selectedImages;
    final selectedCount = selectedImages.length;

    return Container(
      width: double.infinity,
      height: 175,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _inputBorder),
      ),
      child: selectedCount == 0
          ? GestureDetector(
              onTap: _pickImage,
              child: _buildUploadPrompt(fullSize: true),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = constraints.maxWidth / selectedCount;

                return GestureDetector(
                  onTap: selectedCount < _maxAttachments ? _pickImage : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (
                              var index = 0;
                              index < selectedImages.length;
                              index++
                            )
                              _buildAttachmentTile(
                                selectedImages[index],
                                index,
                                width: tileWidth,
                                addRightGap: index < selectedCount - 1,
                                showAddHint:
                                    index == selectedCount - 1 &&
                                    selectedCount < _maxAttachments,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$selectedCount/$_maxAttachments attachments selected',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildAttachmentTile(
    XFile image,
    int index, {
    required double width,
    required bool addRightGap,
    required bool showAddHint,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: EdgeInsets.only(right: addRightGap ? 8 : 0),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD9E2EC)),
                ),
                child: _buildFilledAttachmentTile(image),
              ),
            ),
            Positioned(
              top: 6,
              right: addRightGap ? 14 : 6,
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
            if (showAddHint)
              Positioned(
                left: 8,
                top: 6,
                child: Tooltip(
                  message: 'Add photo',
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadPrompt({bool fullSize = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.upload_outlined, size: 28, color: Color(0xFF94A3B8)),
        const SizedBox(height: 4),
        Text(
          fullSize ? 'Click to upload' : 'Add Photo',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: fullSize ? 12 : 11,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildFilledAttachmentTile(XFile image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: FutureBuilder<Uint8List>(
        future: image.readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(snapshot.data!, fit: BoxFit.cover),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  color: const Color(0x99000000),
                  child: Text(
                    image.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black38),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
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
