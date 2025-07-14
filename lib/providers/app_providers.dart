import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/dispenser.dart';
import '../models/dose.dart';
import '../models/notification.dart';
import '../models/user.dart' as app_user;

// Service providers
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final databaseServiceProvider = Provider<DatabaseService>((ref) => DatabaseService());
final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

// Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.currentUser;
});

// User profile provider
final userProfileProvider = StreamProvider<app_user.User?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.userProfileStream();
});

// Dispenser provider
final dispenserProvider = StreamProvider<Dispenser>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(Dispenser(
      isOnline: false,
      lastSeen: null,
      chambers: {0: 0, 1: 0, 2: 0, 3: 0},
    ));
  }
  
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.dispenserStream();
});

// All doses provider
final dosesProvider = StreamProvider<List<Dose>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.dosesStream();
});

// Today's doses provider
final todaysDosesProvider = StreamProvider<List<Dose>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.todaysDosesStream();
});

// Upcoming doses provider (next 24 hours)
final upcomingDosesProvider = Provider<List<Dose>>((ref) {
  final dosesAsync = ref.watch(todaysDosesProvider);
  return dosesAsync.when(
    data: (doses) {
      final now = DateTime.now();
      return doses
          .where((dose) => 
              dose.status == DoseStatus.upcoming &&
              dose.time.isAfter(now))
          .take(5)
          .toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Overdue doses provider
final overdueDosesProvider = Provider<List<Dose>>((ref) {
  final dosesAsync = ref.watch(todaysDosesProvider);
  return dosesAsync.when(
    data: (doses) => doses.where((dose) => dose.isOverdue()).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// Notifications provider
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.notificationsStream();
});

// Unread notifications count provider
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(notificationsProvider);
  return notificationsAsync.when(
    data: (notifications) => 
        notifications.where((n) => !n.read).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// Dispenser status provider
final dispenserStatusProvider = Provider<DispenserStatus>((ref) {
  final dispenserAsync = ref.watch(dispenserProvider);
  return dispenserAsync.when(
    data: (dispenser) {
      if (!dispenser.isOnline) return DispenserStatus.offline;
      
      final totalPills = dispenser.getTotalPills();
      if (totalPills == 0) return DispenserStatus.empty;
      if (totalPills <= 20) return DispenserStatus.low;
      
      return DispenserStatus.normal;
    },
    loading: () => DispenserStatus.unknown,
    error: (_, __) => DispenserStatus.error,
  );
});

// Greeting provider
final greetingProvider = Provider<String>((ref) {
  final userProfileAsync = ref.watch(userProfileProvider);
  final hour = DateTime.now().hour;
  
  String greeting;
  if (hour < 12) {
    greeting = 'Good Morning';
  } else if (hour < 17) {
    greeting = 'Good Afternoon';
  } else {
    greeting = 'Good Evening';
  }
  
  return userProfileAsync.when(
    data: (user) => user != null 
        ? '$greeting, ${user.firstName}'
        : greeting,
    loading: () => greeting,
    error: (_, __) => greeting,
  );
});

enum DispenserStatus {
  normal,
  low,
  empty,
  offline,
  unknown,
  error,
}

// State notifier for loading states
class LoadingNotifier extends StateNotifier<bool> {
  LoadingNotifier() : super(false);

  void setLoading(bool loading) {
    state = loading;
  }
}

final loadingProvider = StateNotifierProvider<LoadingNotifier, bool>((ref) {
  return LoadingNotifier();
});

// State notifier for error messages
class ErrorNotifier extends StateNotifier<String?> {
  ErrorNotifier() : super(null);

  void setError(String? error) {
    state = error;
  }

  void clearError() {
    state = null;
  }
}

final errorProvider = StateNotifierProvider<ErrorNotifier, String?>((ref) {
  return ErrorNotifier();
});
