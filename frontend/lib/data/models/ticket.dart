class Ticket {
  final String id;
  final String title;
  final String description;
  final String category;
  final String urgency;
  final String status;
  final String? photoUrl;
  final String tenantId;
  final String unitId;
  final String tenantName;
  final String unitNumber;
  final String propertyName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Ticket({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.urgency,
    required this.status,
    this.photoUrl,
    required this.tenantId,
    required this.unitId,
    this.tenantName = '',
    this.unitNumber = '',
    this.propertyName = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      urgency: json['urgency']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString(),
      tenantId: json['tenant_id']?.toString() ?? '',
      unitId: json['unit_id']?.toString() ?? '',
      tenantName: json['tenant_name']?.toString() ?? '',
      unitNumber: json['unit_number']?.toString() ?? '',
      propertyName: json['property_name']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
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
