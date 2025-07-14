import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _requestPermissions();
    _isInitialized = true;
  }

  Future<void> _requestPermissions() async {
    // Request notification permissions for Android 13+
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Request notification permissions for iOS
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void _onNotificationTap(NotificationResponse response) {
    // TODO: Handle notification tap
    // Navigate to specific screen based on notification payload
    print('Notification tapped: ${response.payload}');
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationType? type,
  }) async {
    if (!_isInitialized) await initialize();

    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      _getChannelId(type),
      _getChannelName(type),
      channelDescription: _getChannelDescription(type),
      importance: _getImportance(type),
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(_getNotificationColor(type) ?? 0xFF2196F3),
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
      macOS: iosNotificationDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> showDoseReminderNotification({
    required String medicationName,
    required String chamber,
    required DateTime doseTime,
    required String doseId,
  }) async {
    await showNotification(
      id: doseId.hashCode,
      title: 'Time for your medication',
      body: '$medicationName from chamber $chamber',
      payload: 'dose_reminder:$doseId',
      type: NotificationType.missedDose,
    );
  }

  Future<void> showLowPillAlert({
    required String chamber,
    required int pillCount,
  }) async {
    await showNotification(
      id: 'low_pill_$chamber'.hashCode,
      title: 'Low Pill Alert',
      body: 'Chamber $chamber has only $pillCount pills remaining',
      payload: 'low_pill:$chamber',
      type: NotificationType.lowPillAlert,
    );
  }

  Future<void> showDispenserOfflineAlert() async {
    await showNotification(
      id: 'dispenser_offline'.hashCode,
      title: 'Dispenser Offline',
      body: 'Your pill dispenser is not connected',
      payload: 'dispenser_offline',
      type: NotificationType.dispenserOffline,
    );
  }

  Future<void> showDoseDispensedNotification({
    required String medicationName,
    required String chamber,
  }) async {
    await showNotification(
      id: 'dose_dispensed_${DateTime.now().millisecondsSinceEpoch}'.hashCode,
      title: 'Dose Dispensed',
      body: '$medicationName has been dispensed from chamber $chamber',
      payload: 'dose_dispensed',
      type: NotificationType.doseDispensed,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  // Schedule daily dose reminder notifications
  Future<void> scheduleDoseReminder({
    required String doseId,
    required String medicationName,
    required String chamber,
    required DateTime scheduleTime,
  }) async {
    // TODO: Implement scheduled notifications
    // This would use timezone package to schedule notifications
    print('Scheduling dose reminder for $medicationName at $scheduleTime');
  }

  String _getChannelId(NotificationType? type) {
    switch (type) {
      case NotificationType.doseDispensed:
        return 'dose_dispensed';
      case NotificationType.missedDose:
        return 'missed_dose';
      case NotificationType.lowPillAlert:
        return 'low_pill_alert';
      case NotificationType.dispenserOffline:
        return 'dispenser_offline';
      default:
        return 'general';
    }
  }

  String _getChannelName(NotificationType? type) {
    switch (type) {
      case NotificationType.doseDispensed:
        return 'Dose Dispensed';
      case NotificationType.missedDose:
        return 'Dose Reminders';
      case NotificationType.lowPillAlert:
        return 'Low Pill Alerts';
      case NotificationType.dispenserOffline:
        return 'Dispenser Status';
      default:
        return 'General Notifications';
    }
  }

  String _getChannelDescription(NotificationType? type) {
    switch (type) {
      case NotificationType.doseDispensed:
        return 'Notifications when doses are successfully dispensed';
      case NotificationType.missedDose:
        return 'Reminders for scheduled medications';
      case NotificationType.lowPillAlert:
        return 'Alerts when pill counts are running low';
      case NotificationType.dispenserOffline:
        return 'Notifications about dispenser connectivity';
      default:
        return 'General app notifications';
    }
  }

  Importance _getImportance(NotificationType? type) {
    switch (type) {
      case NotificationType.missedDose:
        return Importance.high;
      case NotificationType.lowPillAlert:
        return Importance.high;
      case NotificationType.dispenserOffline:
        return Importance.high;
      default:
        return Importance.defaultImportance;
    }
  }

  int? _getNotificationColor(NotificationType? type) {
    switch (type) {
      case NotificationType.doseDispensed:
        return 0xFF4CAF50; // Green
      case NotificationType.missedDose:
        return 0xFFFF9800; // Orange
      case NotificationType.lowPillAlert:
        return 0xFFFF5722; // Red-Orange
      case NotificationType.dispenserOffline:
        return 0xFFF44336; // Red
      default:
        return 0xFF2196F3; // Blue
    }
  }
}
