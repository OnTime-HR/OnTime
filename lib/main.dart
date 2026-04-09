import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'EmployeeDashboard.dart';
import 'splash_screen.dart';
import 'welcome_and_login.dart';
import 'manager_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const OnTimeApp());
}

class OnTimeApp extends StatelessWidget {
  const OnTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnTime',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      // App starts with Splash, which should then navigate to AuthGate
      home: const SplashScreen(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. If not logged in, show Login
        if (!snapshot.hasData) {
          return const WelcomeLoginScreen();
        }

        // 2. If logged in, fetch their profile to check their ROLE
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, userDoc) {
            if (userDoc.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.orange)));
            }

            // 3. ROLE-BASED ROUTING LOGIC
            if (userDoc.hasData && userDoc.data!.exists) {
              // Extract the user data
              Map<String, dynamic> userData = userDoc.data!.data() as Map<String, dynamic>;

              // Get the role (default to 'Employee' if it's missing for some reason)
              String role = userData['role'] ?? 'Employee';

              // Route based on role
              if (role == 'Manager') {
                return const ManagerDashboard();
              } else {
                return const EmployeeDashboard();
              }
            }

            // If logged in but profile creation failed or is missing, show login to retry
            return const WelcomeLoginScreen();
          },
        );
      },
    );
  }
}