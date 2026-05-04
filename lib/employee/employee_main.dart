import 'package:flutter/material.dart';
import 'employee_dashboard.dart';
import 'employee_schedule_screen.dart';

class EmployeeMainScreen extends StatefulWidget {
  const EmployeeMainScreen({super.key});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  int _currentIndex = 0;

  // This function acts as our "Back Option" to return to the Home Dashboard
  void _goToHome() {
    setState(() {
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // These are the screens that will swap out inside the body
    final List<Widget> screens = [
      const EmployeeDashboard(), // Index 0
      const Center(child: Text("Notifications Screen")), // Index 1

      // We pass the back function to the schedule screen!
      EmployeeScheduleScreen(onBack: _goToHome), // Index 2

      const Center(child: Text("More Screen")), // Index 3
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      // IndexedStack keeps the state of the pages alive so they don't reload!
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      // THE FIXED NAVIGATION BAR
      bottomNavigationBar: BottomNavigationBar(
        elevation: 15,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey.shade400,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Switches the screen smoothly
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: "Notification"),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "Schedule"),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: "More"),
        ],
      ),
    );
  }
}