enum NotificationType {
  doseDispensed,
  missedDose,
  lowPillAlert,
  dispenserOffline,
  general,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String message;
  final DateTime timestamp;
  final bool read;
  final Map<String, dynamic>? data;

  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
    this.read = false,
    this.data,
  });

  factory AppNotification.fromJson(String id, Map<String, dynamic> json) {
    return AppNotification(
      id: id,
      type: NotificationType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => NotificationType.general,
      ),
      message: json['message'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      read: json['read'] ?? false,
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'read': read,
      'data': data,
    };
  }

  String get typeDisplayName {
    switch (type) {
      case NotificationType.doseDispensed:
        return 'Dose Dispensed';
      case NotificationType.missedDose:
        return 'Missed Dose';
      case NotificationType.lowPillAlert:
        return 'Low Pill Alert';
      case NotificationType.dispenserOffline:
        return 'Dispenser Offline';
      case NotificationType.general:
        return 'General';
    }
  }

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? message,
    DateTime? timestamp,
    bool? read,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
      data: data ?? this.data,
    );
  }
}
