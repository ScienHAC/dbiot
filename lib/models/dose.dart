enum DoseStatus {
  upcoming,
  taken,
  missed,
}

class Dose {
  final String id;
  final String name;
  final int chamber; // 0, 1, 2, 3 (matching ESP32 expectations)
  final DateTime time;
  final DateTime startDate;
  final DateTime endDate;
  final int count;
  final String? conditions;
  final DoseStatus status;
  final DateTime? takenAt;
  final bool dispensed; // For ESP32 compatibility
  final String? lastDispensed; // For ESP32 compatibility

  const Dose({
    required this.id,
    required this.name,
    required this.chamber,
    required this.time,
    required this.startDate,
    required this.endDate,
    required this.count,
    this.conditions,
    this.status = DoseStatus.upcoming,
    this.takenAt,
    this.dispensed = false,
    this.lastDispensed,
  });

  factory Dose.fromJson(String id, Map<String, dynamic> json) {
    // Handle both new format (chamber as int) and old format (chamber as string)
    int chamberValue;
    if (json['chamber'] is String) {
      // Convert A,B,C,D to 0,1,2,3
      final chamberStr = json['chamber'] as String;
      chamberValue = ['A', 'B', 'C', 'D'].indexOf(chamberStr.toUpperCase());
      if (chamberValue == -1) chamberValue = 0; // Default to chamber 0
    } else {
      chamberValue = json['chamber'] ?? 0;
    }
    
    return Dose(
      id: id,
      name: json['name'] ?? '',
      chamber: chamberValue,
      time: json['time'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['time'])
          : DateTime.now(),
      startDate: json['startDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['startDate'])
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['endDate'])
          : DateTime.now().add(const Duration(days: 30)),
      count: json['count'] ?? 1,
      conditions: json['conditions'],
      status: json['status'] != null
          ? DoseStatus.values.firstWhere(
              (status) => status.name == json['status'],
              orElse: () => DoseStatus.upcoming,
            )
          : DoseStatus.upcoming,
      takenAt: json['takenAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['takenAt'])
          : null,
      dispensed: json['dispensed'] ?? false,
      lastDispensed: json['lastDispensed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'chamber': chamber,
      'time': time.millisecondsSinceEpoch,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'count': count,
      'conditions': conditions,
      'status': status.name,
      'takenAt': takenAt?.millisecondsSinceEpoch,
      'dispensed': dispensed,
      'lastDispensed': lastDispensed,
    };
  }

  // Convert to ESP32 format for Firebase
  Map<String, dynamic> toEsp32Json() {
    return {
      'name': name,
      'chamber': chamber,
      'hour': time.hour,
      'minute': time.minute,
      'dispensed': dispensed,
      'lastDispensed': lastDispensed ?? '',
    };
  }

  bool isScheduledForToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return startDate.isBefore(today.add(const Duration(days: 1))) &&
           endDate.isAfter(today.subtract(const Duration(days: 1)));
  }

  bool isOverdue() {
    if (status != DoseStatus.upcoming) return false;
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    return now.isAfter(scheduledTime.add(const Duration(minutes: 15)));
  }

  Dose copyWith({
    String? id,
    String? name,
    String? chamber,
    DateTime? time,
    DateTime? startDate,
    DateTime? endDate,
    int? count,
    String? conditions,
    DoseStatus? status,
    DateTime? takenAt,
  }) {
    return Dose(
      id: id ?? this.id,
      name: name ?? this.name,
      chamber: chamber ?? this.chamber,
      time: time ?? this.time,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      count: count ?? this.count,
      conditions: conditions ?? this.conditions,
      status: status ?? this.status,
      takenAt: takenAt ?? this.takenAt,
    );
  }
}
