class NotificationModel {
  final int notificationId;
  final String title;
  final String body;
  final String eventType;
  final int? referenceId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.eventType,
    this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json['notificationId'] is int
          ? json['notificationId']
          : int.tryParse(json['notificationId']?.toString() ?? '0') ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      eventType: json['eventType'] ?? '',
      referenceId: json['referenceId'] != null
          ? (json['referenceId'] is int
              ? json['referenceId']
              : int.tryParse(json['referenceId'].toString()))
          : null,
      isRead: json['read'] ?? json['isRead'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  NotificationModel copyWith({
    bool? isRead,
  }) {
    return NotificationModel(
      notificationId: notificationId,
      title: title,
      body: body,
      eventType: eventType,
      referenceId: referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
