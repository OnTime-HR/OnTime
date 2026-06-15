import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ontime/shared/pin_screen.dart'; // Ensure this path is correct
import 'employee_dashboard.dart';
import 'employee_schedule_screen.dart';
import 'notification_screen.dart';
import 'package:ontime/shared/profile_screen.dart';

class EmployeeMainScreen extends StatefulWidget {
  const EmployeeMainScreen({super.key});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot>? _notificationSub;
  late final List<Widget> _screens;
  bool _isBackgrounded = false;
  bool _isFirstLoad = true; // NEW: Flag to prevent popups on initial load

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _screens = [
      const EmployeeDashboard(),
      const NotificationScreen(),
      EmployeeScheduleScreen(onBack: _goToHome),
      const ProfileScreen(),
      const Center(child: Text("Profile/More Screen")),
    ];

    // CHANGED: Upgraded listener
    _listenForRealTimeNotifications();
  }

  // --- NEW: REAL-TIME LISTENER ---
  void _listenForRealTimeNotifications() {
    if (currentUser != null) {
      _notificationSub = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true) // Sort to easily find the newest
          .snapshots()
          .listen((snapshot) {

        if (!mounted) return;

        // 1. Update the bottom navbar badge
        setState(() {
          _unreadCount = snapshot.docs.where((doc) => doc['isRead'] == false).length;
        });

        // 2. Check for brand new notifications and show a popup
        if (!_isFirstLoad) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              var data = change.doc.data() as Map<String, dynamic>;
              if (data['isRead'] == false) {
                _showIncomingNotificationPopup(data);
              }
            }
          }
        }
        _isFirstLoad = false;
      });
    }
  }

  // --- NEW: DYNAMIC POPUP UI ---
  void _showIncomingNotificationPopup(Map<String, dynamic> data) {
    String title = data['title'] ?? 'New Notification';
    String body = data['body'] ?? '';
    String type = data['type'] ?? 'info';

    if (type == 'emergency') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.redAccent, width: 3),
          ),
          title: const Row(
            children: [
              Icon(Icons.emergency, color: Colors.red, size: 32),
              SizedBox(width: 10),
              Text("EMERGENCY ALERT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Text(body, style: const TextStyle(fontSize: 15)),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context),
              child: const Text("Acknowledge", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      Color bgColor = Colors.blue.shade600;
      IconData icon = Icons.info_outline;

      if (type == 'success') {
        bgColor = Colors.green.shade600;
        icon = Icons.check_circle_outline;
      } else if (type == 'error') {
        bgColor = Colors.red.shade600;
        icon = Icons.error_outline;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isBackgrounded = true;
    } else if (state == AppLifecycleState.resumed) {
      if (_isBackgrounded) {
        _isBackgrounded = false;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const PinScreen(isCreatingPin: false, userRole: 'Employee'),
          ),
              (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
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