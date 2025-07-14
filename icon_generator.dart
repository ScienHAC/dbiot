import 'package:flutter/material.dart';

void main() {
  runApp(const IconGeneratorApp());
}

class IconGeneratorApp extends StatelessWidget {
  const IconGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.grey[300],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Take a screenshot of the icon below and save as app_icon.png',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // The icon to screenshot
              Container(
                width: 512,
                height: 512,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(90),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
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
                      size: 250,
                      color: Colors.white,
                    ),
                    // Plus sign
                    Positioned(
                      right: 60,
                      top: 60,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Save this as: assets/icon/app_icon.png\nThen run: flutter pub run flutter_launcher_icons',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
