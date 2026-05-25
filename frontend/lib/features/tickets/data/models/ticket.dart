class Ticket {
  final String id;
  final String title;
  final String description;
  final String category;
  final String urgency;
  final String status;
  final List<String> photoUrls;
  final bool isPrivate;
  final String tenantId;
  final String unitId;
  final String tenantName;
  final String unitNumber;
  final String propertyName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String slaStatus;
  final int? responseTimeMinutes;
  final int? resolutionTimeMinutes;
  final int? closureTimeMinutes;
  final bool isSlaBreached;
  final bool isRecurringIssue;
  final int recurringIssueCount;
  final String? recurringIssueMessage;

  Ticket({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.urgency,
    required this.status,
    this.photoUrls = const [],
    this.isPrivate = false,
    required this.tenantId,
    required this.unitId,
    this.tenantName = '',
    this.unitNumber = '',
    this.propertyName = '',
    required this.createdAt,
    required this.updatedAt,
    this.slaStatus = 'On Track',
    this.responseTimeMinutes,
    this.resolutionTimeMinutes,
    this.closureTimeMinutes,
    this.isSlaBreached = false,
    this.isRecurringIssue = false,
    this.recurringIssueCount = 0,
    this.recurringIssueMessage,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      urgency: json['urgency']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      photoUrls:
          (json['photo_urls'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          (json['photo_url'] != null
              ? [json['photo_url'].toString()]
              : const []),
      isPrivate: json['is_private'] == true,
      tenantId: json['tenant_id']?.toString() ?? '',
      unitId: json['unit_id']?.toString() ?? '',
      tenantName: json['tenant_name']?.toString() ?? '',
      unitNumber: json['unit_number']?.toString() ?? '',
      propertyName: json['property_name']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      slaStatus: json['sla_status']?.toString() ?? 'On Track',
      responseTimeMinutes: _intFromJson(json['response_time_minutes']),
      resolutionTimeMinutes: _intFromJson(json['resolution_time_minutes']),
      closureTimeMinutes: _intFromJson(json['closure_time_minutes']),
      isSlaBreached: json['is_sla_breached'] == true,
      isRecurringIssue: json['is_recurring_issue'] == true,
      recurringIssueCount: _intFromJson(json['recurring_issue_count']) ?? 0,
      recurringIssueMessage: json['recurring_issue_message']?.toString(),
    );
  }

  static int? _intFromJson(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String get statusLabel {
    switch (status) {
      case 'opened':
        return 'TICKET OPENED';
      case 'acknowledged':
        return 'PROBLEM ACKNOWLEDGED';
      case 'in_progress':
        return 'RESOLVING IN PROGRESS';
      case 'resolved':
        return 'PROBLEM RESOLVED';
      case 'closed':
        return 'TICKET CLOSED';
      default:
        return status.toUpperCase();
    }
  }

  String get urgencyLabel {
    return '${urgency.toUpperCase()} PRIORITY';
  }

  String get nextStatus {
    switch (status) {
      case 'opened':
        return 'acknowledged';
      case 'acknowledged':
        return 'in_progress';
      case 'in_progress':
        return 'resolved';
      case 'resolved':
        return 'closed';
      default:
        return '';
    }
  }

  String get nextStatusActionLabel {
    switch (status) {
      case 'opened':
        return 'Acknowledge';
      case 'acknowledged':
        return 'Start Progress';
      case 'in_progress':
        return 'Mark as Resolved';
      case 'resolved':
        return 'Close Ticket';
      default:
        return '';
    }
  }

  bool get isClosed => status == 'closed';

  String? get photoUrl => photoUrls.isEmpty ? null : photoUrls.first;

  String? get responseTimeLabel => _formatDuration(responseTimeMinutes);
  String? get resolutionTimeLabel => _formatDuration(resolutionTimeMinutes);
  String? get closureTimeLabel => _formatDuration(closureTimeMinutes);

  static String? _formatDuration(int? minutes) {
    if (minutes == null) return null;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours < 24) return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
    final days = hours ~/ 24;
    final remHours = hours % 24;
    return remHours == 0 ? '${days}d' : '${days}d ${remHours}h';
  }
}

class CategoryCount {
  final String category;
  final int count;

  CategoryCount({required this.category, required this.count});

  factory CategoryCount.fromJson(Map<String, dynamic> json) {
    return CategoryCount(
      category: json['category']?.toString() ?? '',
      count: Ticket._intFromJson(json['count']) ?? 0,
    );
  }
}

class RecurringIssue {
  final String unitId;
  final String unitNumber;
  final String category;
  final int count;
  final String message;

  RecurringIssue({
    required this.unitId,
    this.unitNumber = '',
    required this.category,
    required this.count,
    required this.message,
  });

  factory RecurringIssue.fromJson(Map<String, dynamic> json) {
    return RecurringIssue(
      unitId: json['unit_id']?.toString() ?? '',
      unitNumber: json['unit_number']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      count: Ticket._intFromJson(json['count']) ?? 0,
      message: json['message']?.toString() ?? '',
    );
  }
}

class TicketAnalyticsSummary {
  final int totalTickets;
  final int openTickets;
  final int resolvedTickets;
  final int closedTickets;
  final int? averageResponseTimeMinutes;
  final int? averageResolutionTimeMinutes;
  final int slaBreachCount;
  final List<CategoryCount> mostCommonCategories;
  final int recurringIssueCount;
  final List<RecurringIssue> recurringIssues;

  TicketAnalyticsSummary({
    required this.totalTickets,
    required this.openTickets,
    required this.resolvedTickets,
    required this.closedTickets,
    this.averageResponseTimeMinutes,
    this.averageResolutionTimeMinutes,
    required this.slaBreachCount,
    this.mostCommonCategories = const [],
    required this.recurringIssueCount,
    this.recurringIssues = const [],
  });

  factory TicketAnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return TicketAnalyticsSummary(
      totalTickets: Ticket._intFromJson(json['total_tickets']) ?? 0,
      openTickets: Ticket._intFromJson(json['open_tickets']) ?? 0,
      resolvedTickets: Ticket._intFromJson(json['resolved_tickets']) ?? 0,
      closedTickets: Ticket._intFromJson(json['closed_tickets']) ?? 0,
      averageResponseTimeMinutes: Ticket._intFromJson(
        json['average_response_time_minutes'],
      ),
      averageResolutionTimeMinutes: Ticket._intFromJson(
        json['average_resolution_time_minutes'],
      ),
      slaBreachCount: Ticket._intFromJson(json['sla_breach_count']) ?? 0,
      mostCommonCategories:
          (json['most_common_categories'] as List<dynamic>?)
              ?.map(
                (item) =>
                    CategoryCount.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList() ??
          const [],
      recurringIssueCount:
          Ticket._intFromJson(json['recurring_issue_count']) ?? 0,
      recurringIssues:
          (json['recurring_issues'] as List<dynamic>?)
              ?.map(
                (item) =>
                    RecurringIssue.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList() ??
          const [],
    );
  }

  String? get averageResponseTimeLabel =>
      Ticket._formatDuration(averageResponseTimeMinutes);
  String? get averageResolutionTimeLabel =>
      Ticket._formatDuration(averageResolutionTimeMinutes);
}

class AuditLogEntry {
  final String id;
  final String? fromStatus;
  final String toStatus;
  final String? note;
  final String actorId;
  final String actorName;
  final DateTime createdAt;

  AuditLogEntry({
    required this.id,
    this.fromStatus,
    required this.toStatus,
    this.note,
    required this.actorId,
    this.actorName = '',
    required this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'],
      fromStatus: json['from_status'],
      toStatus: json['to_status'],
      note: json['note'],
      actorId: json['actor_id'],
      actorName: json['actor_name'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get statusLabel {
    switch (toStatus) {
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
        return toStatus;
    }
  }
}

class TicketMessage {
  final String id;
  final String content;
  final String? photoUrl;
  final String senderId;
  final String senderName;
  final DateTime createdAt;

  TicketMessage({
    required this.id,
    required this.content,
    this.photoUrl,
    required this.senderId,
    this.senderName = '',
    required this.createdAt,
  });

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    return TicketMessage(
      id: json['id'],
      content: json['content'] ?? '',
      photoUrl: json['photo_url'],
      senderId: json['sender_id'],
      senderName: json['sender_name'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class UserInfo {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? unitId;

  UserInfo({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.unitId,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      role: json['role'],
      unitId: json['unit_id'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'role': role,
    'unit_id': unitId,
  };
}

// ── Dropdown constants for ticket creation ───────────────────────────────────

class TicketCategory {
  static const List<Map<String, String>> values = [
    {'value': 'plumbing', 'label': 'Plumbing'},
    {'value': 'electrical', 'label': 'Electrical'},
    {'value': 'hvac', 'label': 'HVAC'},
    {'value': 'appliance', 'label': 'Appliance'},
    {'value': 'structural', 'label': 'Structural'},
    {'value': 'pest_control', 'label': 'Pest Control'},
    {'value': 'other', 'label': 'Other'},
  ];
}

class TicketUrgency {
  static const List<Map<String, String>> values = [
    {'value': 'low', 'label': 'Low'},
    {'value': 'normal', 'label': 'Normal'},
    {'value': 'urgent', 'label': 'Urgent'},
  ];
}

class Property {
  final String id;
  final String name;
  final String address;

  Property({
    required this.id,
    required this.name,
    this.address = '',
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }
}

class ManagerUnit {
  final String id;
  final String unitNumber;
  final String propertyName;

  ManagerUnit({
    required this.id,
    required this.unitNumber,
    this.propertyName = '',
  });

  factory ManagerUnit.fromJson(Map<String, dynamic> json) {
    return ManagerUnit(
      id: json['id']?.toString() ?? '',
      unitNumber: json['unit_number']?.toString() ?? '',
      propertyName: json['property_name']?.toString() ?? '',
    );
  }
}
