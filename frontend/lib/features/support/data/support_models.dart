class SupportMessage {
  final String id;
  final String content;
  final String? photoUrl;
  final String senderId;
  final String senderName;
  final DateTime createdAt;

  SupportMessage({
    required this.id,
    required this.content,
    this.photoUrl,
    required this.senderId,
    this.senderName = '',
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString(),
      senderId: json['sender_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class SupportContact {
  final String tenantId;
  final String tenantName;
  final String tenantEmail;
  final String? unitId;
  final String unitNumber;
  final String propertyId;
  final String propertyName;
  final String lastMessage;
  final DateTime? lastMessageAt;

  SupportContact({
    required this.tenantId,
    required this.tenantName,
    required this.tenantEmail,
    this.unitId,
    this.unitNumber = '',
    required this.propertyId,
    required this.propertyName,
    this.lastMessage = '',
    this.lastMessageAt,
  });

  factory SupportContact.fromJson(Map<String, dynamic> json) {
    return SupportContact(
      tenantId: json['tenant_id']?.toString() ?? '',
      tenantName: json['tenant_name']?.toString() ?? '',
      tenantEmail: json['tenant_email']?.toString() ?? '',
      unitId: json['unit_id']?.toString(),
      unitNumber: json['unit_number']?.toString() ?? '',
      propertyId: json['property_id']?.toString() ?? '',
      propertyName: json['property_name']?.toString() ?? '',
      lastMessage: json['last_message']?.toString() ?? '',
      lastMessageAt: json['last_message_at'] == null
          ? null
          : DateTime.parse(json['last_message_at']),
    );
  }
}
