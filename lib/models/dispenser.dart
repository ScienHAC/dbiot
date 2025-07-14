class Dispenser {
  final bool isOnline; // ESP32 expects "isOnline" not "status"
  final DateTime? lastSeen; // ESP32 expects "lastSeen"
  final bool lastDispenseSuccessful; // ESP32 tracks this
  final String? lastDispenseTime; // ESP32 format: "HH:MM:SS"
  final Map<int, int> chambers; // Chamber number (0-3) to pill count

  const Dispenser({
    required this.isOnline,
    this.lastSeen,
    this.lastDispenseSuccessful = false,
    this.lastDispenseTime,
    required this.chambers,
  });

  factory Dispenser.fromJson(Map<String, dynamic> json) {
    // Handle chambers data - convert from any format to int keys
    Map<int, int> chambersMap = {};
    
    if (json['chambers'] != null) {
      final chambersData = json['chambers'] as Map<String, dynamic>;
      chambersData.forEach((key, value) {
        int chamberNum;
        if (key is String) {
          // Convert A,B,C,D to 0,1,2,3
          chamberNum = ['A', 'B', 'C', 'D'].indexOf(key.toUpperCase());
          if (chamberNum == -1) {
            // Try parsing as number
            chamberNum = int.tryParse(key) ?? 0;
          }
        } else {
          chamberNum = int.tryParse(key.toString()) ?? 0;
        }
        chambersMap[chamberNum] = (value as num?)?.toInt() ?? 0;
      });
    } else {
      // Default chambers
      chambersMap = {0: 0, 1: 0, 2: 0, 3: 0};
    }

    DateTime? lastSeenDateTime;
    if (json['lastSeen'] != null) {
      if (json['lastSeen'] is num) {
        lastSeenDateTime = DateTime.fromMillisecondsSinceEpoch(json['lastSeen']);
      } else {
        // Try to parse string format from ESP32
        try {
          lastSeenDateTime = DateTime.parse(json['lastSeen']);
        } catch (e) {
          lastSeenDateTime = DateTime.now();
        }
      }
    }

    // Handle legacy format
    if (json.containsKey('status')) {
      final status = json['status'] as String?;
      return Dispenser(
        isOnline: status == 'online',
        lastSeen: json['lastActive'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['lastActive'])
            : lastSeenDateTime,
        lastDispenseSuccessful: json['lastDispenseSuccessful'] ?? false,
        lastDispenseTime: json['lastDispenseTime'],
        chambers: _convertLegacyChambers(json['chambers']),
      );
    }

    return Dispenser(
      isOnline: json['isOnline'] ?? false,
      lastSeen: lastSeenDateTime,
      lastDispenseSuccessful: json['lastDispenseSuccessful'] ?? false,
      lastDispenseTime: json['lastDispenseTime'],
      chambers: chambersMap,
    );
  }

  static Map<int, int> _convertLegacyChambers(dynamic chambersData) {
    Map<int, int> result = {0: 0, 1: 0, 2: 0, 3: 0};
    
    if (chambersData is Map) {
      chambersData.forEach((key, value) {
        int chamberNum;
        if (key is String) {
          chamberNum = ['A', 'B', 'C', 'D'].indexOf(key.toUpperCase());
          if (chamberNum == -1) {
            chamberNum = int.tryParse(key) ?? 0;
          }
        } else {
          chamberNum = int.tryParse(key.toString()) ?? 0;
        }
        if (chamberNum >= 0 && chamberNum <= 3) {
          result[chamberNum] = (value as num?)?.toInt() ?? 0;
        }
      });
    }
    
    return result;
  }

  Map<String, dynamic> toJson() {
    return {
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'lastDispenseSuccessful': lastDispenseSuccessful,
      'lastDispenseTime': lastDispenseTime,
      'chambers': chambers,
    };
  }

  // Convert to ESP32 format
  Map<String, dynamic> toEsp32Json() {
    return {
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'lastDispenseSuccessful': lastDispenseSuccessful,
      'lastDispenseTime': lastDispenseTime ?? '',
    };
  }

  int getTotalPills() {
    return chambers.values.fold(0, (sum, count) => sum + count);
  }

  String getChamberDisplayName(int chamber) {
    return ['A', 'B', 'C', 'D'][chamber] ?? 'Unknown';
  }

  Dispenser copyWith({
    bool? isOnline,
    DateTime? lastSeen,
    bool? lastDispenseSuccessful,
    String? lastDispenseTime,
    Map<int, int>? chambers,
  }) {
    return Dispenser(
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      lastDispenseSuccessful: lastDispenseSuccessful ?? this.lastDispenseSuccessful,
      lastDispenseTime: lastDispenseTime ?? this.lastDispenseTime,
      chambers: chambers ?? this.chambers,
    );
  }
}
