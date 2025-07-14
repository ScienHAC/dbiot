import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/auth/login_screen.dart';

class SimpleSplashScreen extends ConsumerStatefulWidget {
  const SimpleSplashScreen({super.key});

  @override
  ConsumerState<SimpleSplashScreen> createState() => _SimpleSplashScreenState();
}

class _SimpleSplashScreenState extends ConsumerState<SimpleSplashScreen> 
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    print('SimpleSplashScreen: initState called');
    
    // Initialize animation controllers
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Setup animations
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Start animations with delays
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _scaleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _rotationController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _fadeController.forward();
    });
    
    // Navigate to login after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      print('SimpleSplashScreen: Navigating to login');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('SimpleSplashScreen: build called');
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo with plus sign
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Main pill icon
                            const Icon(
                              Icons.medication,
                              size: 50,
                              color: Color(0xFF2196F3),
                            ),
                            // Animated plus sign
                            Positioned(
                              right: 5,
                              top: 5,
                              child: Transform.rotate(
                                angle: _rotationAnimation.value * 2 * 3.14159,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            // Animated title
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Text(
                'PillDoseBuddy',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Animated subtitle
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Text(
                'Smart Pill Dispenser',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 50),
            // Animated loading indicator
            FadeTransition(
              opacity: _fadeAnimation,
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
