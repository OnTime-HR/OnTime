import 'package:flutter/material.dart';
import 'manager_dashboard.dart';
import 'package:ontime/manager/team_screen.dart';
import 'package:ontime/manager/calendar_screen.dart';

class ManagerMainScreen extends StatefulWidget {
  const ManagerMainScreen({super.key});

  @override
  State<ManagerMainScreen> createState() => _ManagerMainScreenState();
}

class _ManagerMainScreenState extends State<ManagerMainScreen> {
  int _currentIndex = 0;

  // Initialize the screens ONCE so they don't tear down on tap
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const ManagerDashboard(),
      const TeamScreen(),
      const CalendarScreen(),
      const Center(child: Text("Manager Settings Coming Soon")),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      // IndexedStack keeps your pages alive so they don't reload or blink
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // Wrapped in Theme to kill the tap ripple/blink
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
              _currentIndex = index; // Changes the tab smoothly!
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