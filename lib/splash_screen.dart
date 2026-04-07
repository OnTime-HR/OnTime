import 'package:flutter/material.dart';
import 'main.dart'; // Import main.dart to access AuthGate

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // THE FIX: Navigate to AuthGate, not GetStartedScreen
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthGate()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Make sure this asset exists in your pubspec.yaml!
                Image.asset(
                  'assets/logo.png',
                  width: 100,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.access_time_filled, size: 100, color: Colors.orange),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 30),
              child: Text(
                "By CIS 9.0",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}