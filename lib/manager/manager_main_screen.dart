import 'package:flutter/material.dart';
import 'package:ontime/shared/pin_screen.dart'; // Ensure this path is correct
import 'manager_dashboard.dart';
import 'package:ontime/manager/team_screen.dart';
import 'package:ontime/manager/calendar_screen.dart';

class ManagerMainScreen extends StatefulWidget {
  const ManagerMainScreen({super.key});

  @override
  State<ManagerMainScreen> createState() => _ManagerMainScreenState();
}

// 1. Add 'with WidgetsBindingObserver' to the state class
class _ManagerMainScreenState extends State<ManagerMainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // 2. Start listening to app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    _screens = [
      const ManagerDashboard(),
      const TeamScreen(),
      const CalendarScreen(),
      const Center(child: Text("Manager Settings Coming Soon")),
    ];
  }

  // 3. Add this function to handle when the app goes to background/foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When app is reopened, force them to the PIN screen to unlock
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const PinScreen(isCreatingPin: false, userRole: 'Manager'),
        ),
            (route) => false,
      );
    }
  }

  @override
  void dispose() {
    // 4. Remove the observer to prevent memory leaks
    WidgetsBinding.instance.removeObserver(this);
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