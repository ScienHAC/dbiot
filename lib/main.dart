import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'theme/pill_dose_buddy_theme.dart';
import 'screens/simple_splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables with better error handling
  try {
    await dotenv.load(fileName: ".env");
    print('Environment variables loaded successfully');
    print('API_KEY: ${dotenv.env['API_KEY']?.substring(0, 10)}...');
  } catch (e) {
    print('Warning: Could not load .env file: $e');
    print('Proceeding with default Firebase configuration...');
  }
  
  try {
    // Initialize Firebase with explicit error handling
    print('Starting Firebase initialization...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
    print('Error details: ${e.runtimeType}');
    // Continue even if Firebase fails for now
  }
  
  // Initialize notification service (commented out temporarily for debugging)
  // await NotificationService().initialize();
  
  print('Starting app...');
  runApp(const ProviderScope(child: PillDoseBuddyApp()));
}

class PillDoseBuddyApp extends StatelessWidget {
  const PillDoseBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('PillDoseBuddyApp: build method called');
    return MaterialApp(
      title: 'PillDoseBuddy',
      theme: PillDoseBuddyTheme.lightTheme,
      darkTheme: PillDoseBuddyTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SimpleSplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
