import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/dispenser.dart';
import '../models/dose.dart';
import '../models/notification.dart';
import '../models/user.dart' as app_user;

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  String get _currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  DatabaseReference get _userRef =>
      _database.ref().child('users').child(_currentUserId);

  // Firebase paths that ESP32 expects
  DatabaseReference get _medicationsRef => _database.ref().child('medications');
  DatabaseReference get _pillDispenserRef => _database.ref().child('pillDispenser');

  // Dispenser related methods
  Stream<Dispenser> dispenserStream() {
    return _pillDispenserRef.onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) {
        return Dispenser(
          isOnline: false,
          lastSeen: null,
          chambers: {0: 0, 1: 0, 2: 0, 3: 0},
        );
      }
      return Dispenser.fromJson(Map<String, dynamic>.from(data));
    });
  }

  Future<void> updateDispenserStatus(bool isOnline) async {
    await _pillDispenserRef.update({
      'isOnline': isOnline,
      'lastSeen': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateChamberPillCount(int chamber, int count) async {
    await _pillDispenserRef.child('chambers').update({
      chamber.toString(): count,
    });
  }

  Future<void> syncDispenserCommand() async {
    // ESP32 will see this as a dispenser status update
    await _pillDispenserRef.update({
      'isOnline': true,
      'lastSeen': DateTime.now().toIso8601String(),
    });
  }

  // Dose related methods
  Stream<List<Dose>> dosesStream() {
    return _medicationsRef.onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      return data.entries
          .map((entry) => Dose.fromJson(
                entry.key.toString(),
                Map<String, dynamic>.from(entry.value),
              ))
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
    });
  }

  Stream<List<Dose>> todaysDosesStream() {
    return dosesStream().map((doses) {
      return doses.where((dose) => dose.isScheduledForToday()).toList();
    });
  }

  Future<void> addOrUpdateDose(Dose dose) async {
    final doseRef = dose.id.isEmpty
        ? _medicationsRef.push()
        : _medicationsRef.child(dose.id);

    // Save in ESP32 compatible format
    final esp32Data = dose.toEsp32Json();
    
    // Also save additional app data in user's personal space for app features
    final appData = dose.toJson();
    
    await Future.wait([
      doseRef.set(esp32Data), // ESP32 format
      _userRef.child('doses').child(doseRef.key ?? dose.id).set(appData), // App format
    ]);
  }

  Future<void> deleteDose(String doseId) async {
    await Future.wait([
      _medicationsRef.child(doseId).remove(),
      _userRef.child('doses').child(doseId).remove(),
    ]);
  }

  Future<void> markDoseAsTaken(String doseId) async {
    final now = DateTime.now();
    
    // Update ESP32 format
    await _medicationsRef.child(doseId).update({
      'dispensed': true,
      'lastDispensed': now.toIso8601String(),
    });
    
    // Update app format
    await _userRef.child('doses').child(doseId).update({
      'status': DoseStatus.taken.name,
      'takenAt': now.millisecondsSinceEpoch,
      'dispensed': true,
      'lastDispensed': now.toIso8601String(),
    });

    // Add notification
    await _addNotification(
      type: NotificationType.doseDispensed,
      message: 'Dose has been taken successfully',
      data: {'doseId': doseId},
    );
  }

  Future<void> markDoseAsMissed(String doseId) async {
    // Update app format only (ESP32 doesn't track missed status)
    await _userRef.child('doses').child(doseId).update({
      'status': DoseStatus.missed.name,
    });

    // Add notification
    await _addNotification(
      type: NotificationType.missedDose,
      message: 'Dose was missed',
      data: {'doseId': doseId},
    );
  }

  // Notification related methods
  Stream<List<AppNotification>> notificationsStream() {
    return _userRef.child('notifications').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <AppNotification>[];

      return data.entries
          .map((entry) => AppNotification.fromJson(
                entry.key.toString(),
                Map<String, dynamic>.from(entry.value),
              ))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  Future<void> _addNotification({
    required NotificationType type,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    final notification = AppNotification(
      id: '',
      type: type,
      message: message,
      timestamp: DateTime.now(),
      data: data,
    );

    await _userRef.child('notifications').push().set(notification.toJson());
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _userRef.child('notifications').child(notificationId).update({
      'read': true,
    });
  }

  Future<void> markAllNotificationsAsRead() async {
    final notificationsRef = _userRef.child('notifications');
    final snapshot = await notificationsRef.get();
    final data = snapshot.value as Map<dynamic, dynamic>?;

    if (data != null) {
      final updates = <String, dynamic>{};
      for (final key in data.keys) {
        updates['$key/read'] = true;
      }
      await notificationsRef.update(updates);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    await _userRef.child('notifications').child(notificationId).remove();
  }

  // User profile methods
  Future<void> updateUserProfile(app_user.User user) async {
    await _userRef.child('profile').set(user.toJson());
  }

  Stream<app_user.User?> userProfileStream() {
    return _userRef.child('profile').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return null;

      return app_user.User.fromJson(
        _currentUserId,
        Map<String, dynamic>.from(data),
      );
    });
  }

  // Utility methods
  Future<void> initializeUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Check if user data already exists
    final snapshot = await _userRef.get();
    if (snapshot.exists) return;

    // Initialize default user data (app-specific data only)
    final userData = {
      'profile': {
        'email': user.email,
        'displayName': user.displayName,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
      },
      'doses': {},
      'notifications': {},
    };

    await _userRef.set(userData);

    // Initialize ESP32 data structure if it doesn't exist
    await _initializeEsp32Data();
  }

  Future<void> _initializeEsp32Data() async {
    // Check if ESP32 data exists
    final dispenserSnapshot = await _pillDispenserRef.get();
    if (!dispenserSnapshot.exists) {
      // Initialize dispenser data
      await _pillDispenserRef.set({
        'isOnline': false,
        'lastSeen': DateTime.now().toIso8601String(),
        'lastDispenseSuccessful': false,
        'lastDispenseTime': '',
      });
    }

    final medicationsSnapshot = await _medicationsRef.get();
    if (!medicationsSnapshot.exists) {
      // Initialize medications data
      await _medicationsRef.set({});
    }
  }

  // Monitoring methods for low pill alerts
  void startPillCountMonitoring() {
    dispenserStream().listen((dispenser) {
      for (final entry in dispenser.chambers.entries) {
        final chamberName = dispenser.getChamberDisplayName(entry.key);
        if (entry.value <= 5 && entry.value > 0) {
          _addNotification(
            type: NotificationType.lowPillAlert,
            message: 'Chamber $chamberName is running low on pills (${entry.value} remaining)',
            data: {'chamber': entry.key, 'pillCount': entry.value},
          );
        }
      }

      if (!dispenser.isOnline) {
        final lastSeenText = dispenser.lastSeen != null
            ? dispenser.lastSeen.toString()
            : 'Unknown';
        _addNotification(
          type: NotificationType.dispenserOffline,
          message: 'Dispenser is offline. Last seen: $lastSeenText',
          data: {'lastSeen': dispenser.lastSeen?.millisecondsSinceEpoch},
        );
      }
    });
  }
}
