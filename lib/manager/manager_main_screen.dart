import 'dart:async'; // NEW: Required for the listener
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NEW
import 'package:firebase_auth/firebase_auth.dart'; // NEW
import 'package:ontime/shared/pin_screen.dart';
import 'package:ontime/manager/manager_dashboard.dart';
import 'package:ontime/manager/team_screen.dart';
import 'package:ontime/manager/calendar_screen.dart';
import 'package:ontime/shared/profile_screen.dart';
import 'package:ontime/main.dart';

class ManagerMainScreen extends StatefulWidget {
  const ManagerMainScreen({super.key});

  @override
  State<ManagerMainScreen> createState() => _ManagerMainScreenState();
}

class _ManagerMainScreenState extends State<ManagerMainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  bool _isBackgrounded = false;

  // --- NEW: NOTIFICATION LISTENER VARIABLES ---
  StreamSubscription<QuerySnapshot>? _notificationSub;
  bool _isFirstLoad = true; // Prevents popups from flooding the screen when the app opens

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _screens = [
      const ManagerDashboard(),
      const TeamScreen(),       // Tab 2: The Employee Directory
      const CalendarScreen(),   // Tab 3: The Team Calendar
      const ProfileScreen(),    // Tab 4: Profile & Settings
    ];

    // NEW: Start listening for notifications instantly
    _listenForRealTimeNotifications();
  }

  // --- NEW: REAL-TIME LISTENER ---
  void _listenForRealTimeNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _notificationSub = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {

        if (!mounted) return;

        // Check for brand new notifications and show a popup
        if (!_isFirstLoad) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              var data = change.doc.data() as Map<String, dynamic>;
              // Only pop up if it's currently unread
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

    // If it is an EMERGENCY, force a red dialog box to the center of the screen
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
      // For success, error, or standard notifications, show a sleek top-down Snackbar
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
          margin: const EdgeInsets.only(top: 20, left: 20, right: 20), // Floats at the top
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

        // --- NEW: THE HALL PASS LOGIC ---
        // If they were just picking a photo, ignore the lock and reset the pass!
        if (isPickingMedia) {
          isPickingMedia = false;
          return;
        }
        // --------------------------------

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const PinScreen(isCreatingPin: false, userRole: 'Manager'),
          ),
              (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSub?.cancel(); // NEW: Stop listening when closed
    super.dispose();
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
          elevation: 10,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFF39C12),
          unselectedItemColor: Colors.grey.shade400,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: "Overview"
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: "Team"
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_outlined),
                activeIcon: Icon(Icons.calendar_month),
                label: "Calendar"
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: "Settings"
            ),
          ],
        ),
      ),
    );
  }
}