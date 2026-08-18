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

// Global variable for the camera "hall pass"
bool isPickingMedia = false;

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

// --- CHANGED TO STATEFUL WIDGET ---
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // We declare variables to cache the future so it doesn't run twice!
  Future<List<dynamic>>? _userDataFuture;
  String? _currentUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. If not logged in, show Login
        if (!snapshot.hasData) {
          return const WelcomeLoginScreen();
        }

        // 2. Only fetch the profile and PIN if we haven't done it yet for this user
        if (_userDataFuture == null || _currentUid != snapshot.data!.uid) {
          _currentUid = snapshot.data!.uid;
          _userDataFuture = Future.wait([
            FirebaseFirestore.instance.collection('users').doc(_currentUid).get(),
            SecureStorageHelper().getPin(),
          ]);
        }

        // 3. Pass the CACHED future here instead of generating a new one
        return FutureBuilder(
          future: _userDataFuture,
          builder: (context, AsyncSnapshot<List<dynamic>> futureSnapshot) {
            if (futureSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              );
            }

            // 4. ROLE & PIN ROUTING LOGIC
            if (futureSnapshot.hasData && futureSnapshot.data![0].exists) {

              DocumentSnapshot userDoc = futureSnapshot.data![0];
              String? savedPin = futureSnapshot.data![1];

              Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
              String role = userData['role'] ?? 'Employee';

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