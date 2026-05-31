import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'employee/employee_main.dart';
import 'welcome_and_login.dart';
import 'manager/manager_main_screen.dart';
import 'package:ontime/services/secure_storage_helper.dart';
import 'package:ontime/shared/pin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      home: const AuthGate(),
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

        // 2. If logged in, fetch BOTH their profile AND their saved PIN
        return FutureBuilder(
          future: Future.wait([
            FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            SecureStorageHelper().getPin(), // Fetching the PIN from local storage
          ]),
          builder: (context, AsyncSnapshot<List<dynamic>> futureSnapshot) {
            if (futureSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              );
            }

            // 3. ROLE & PIN ROUTING LOGIC
            if (futureSnapshot.hasData && futureSnapshot.data![0].exists) {

              DocumentSnapshot userDoc = futureSnapshot.data![0];
              String? savedPin = futureSnapshot.data![1]; // Null if it's their first time

              Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
              String role = userData['role'] ?? 'Employee';

              // Instead of going straight to the dashboard, send them to the PinScreen!
              // If savedPin is null, isCreatingPin becomes TRUE.
              return PinScreen(
                isCreatingPin: savedPin == null,
                userRole: role,
              );
            }

            // If logged in but profile creation failed, show login to retry
            return const WelcomeLoginScreen();
          },
        );
      },
    );
  }
}
