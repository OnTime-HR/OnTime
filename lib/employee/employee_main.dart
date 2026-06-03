import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ontime/shared/pin_screen.dart'; // Ensure this path is correct
import 'employee_dashboard.dart';
import 'employee_schedule_screen.dart';
import 'notification_screen.dart';
import 'employee_profile_screen.dart';

class EmployeeMainScreen extends StatefulWidget {
  const EmployeeMainScreen({super.key});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

// 1. Add 'with WidgetsBindingObserver' to the state class
class _EmployeeMainScreenState extends State<EmployeeMainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot>? _notificationSub;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // 2. Start listening to app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    _screens = [
      const EmployeeDashboard(),
      const NotificationScreen(),
      EmployeeScheduleScreen(onBack: _goToHome),
      const EmployeeProfileScreen(),
      const Center(child: Text("Profile/More Screen")),
    ];

    if (currentUser != null) {
      _notificationSub = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _unreadCount = snapshot.docs.length;
          });
        }
      });
    }
  }

  // 3. Add this function to handle when the app goes to background/foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When app is reopened, force them to the PIN screen to unlock
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const PinScreen(isCreatingPin: false, userRole: 'Employee'),
        ),
            (route) => false,
      );
    }
  }

  @override
  void dispose() {
    // 4. Remove the observer to prevent memory leaks
    WidgetsBinding.instance.removeObserver(this);
    _notificationSub?.cancel();
    super.dispose();
  }

  void _goToHome() {
    setState(() {
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          elevation: 15,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey.shade400,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Home"),

            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: _unreadCount > 0,
                backgroundColor: Colors.redAccent,
                label: Text(_unreadCount > 99 ? '99+' : _unreadCount.toString()),
                child: const Icon(Icons.notifications_none),
              ),
              activeIcon: Badge(
                isLabelVisible: _unreadCount > 0,
                backgroundColor: Colors.redAccent,
                label: Text(_unreadCount > 99 ? '99+' : _unreadCount.toString()),
                child: const Icon(Icons.notifications),
              ),
              label: "Inbox",
            ),

            const BottomNavigationBarItem(
                icon: Icon(Icons.grid_view), activeIcon: Icon(Icons.grid_view_rounded), label: "Schedule"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }
}