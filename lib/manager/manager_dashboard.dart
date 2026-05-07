import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'team_screen.dart'; // Make sure this path is correct
import 'calendar_screen.dart'; // Make sure this path is correct
import 'package:ontime/main.dart'; // Adjust path if needed
import 'package:ontime/manager/leave_approvals_screen.dart'; // Adjust path based on where you saved it

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  String managerName = "Manager";

  @override
  void initState() {
    super.initState();
    _fetchManagerData();
  }

  void _fetchManagerData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            managerName = doc.data()?['name'] ?? "Manager";
          });
        }
      } catch (e) {
        debugPrint("Error fetching manager data: $e");
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want to log out?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Closes the dialog
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                // 1. Sign out of Firebase securely
                await FirebaseAuth.instance.signOut();

                if (!context.mounted) return;

                // 2. Force the app back to the AuthGate and clear the screen history
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthGate()),
                      (route) => false,
                );
              },
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Overview",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            Text(
              "Hello, $managerName",
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showLogoutDialog,
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            // 1. Team Stats Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "Present",
                    "42",
                    Icons.people_outline,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    "On Leave",
                    "3",
                    Icons.event_busy,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // 2. Pending Leave Requests Section (LIVE FIREBASE DATA)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Pending Approvals",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to the full approvals screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LeaveApprovalsScreen()),
                    );
                  },
                  child: const Text(
                    "View All",
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // --- LIVE FIREBASE PREVIEW (Top 2 Requests) ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('leave_requests')
                  .where('approverId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .where('status', isEqualTo: 'Pending')
                  .orderBy('appliedAt', descending: true)
                  .limit(2) // Only show the first 2 on the dashboard
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: Colors.orange),
                  ));
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("No pending requests right now. Great job! 🎉", style: TextStyle(color: Colors.grey)),
                  );
                }

                // If we have data, build the preview cards
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String name = data['userName'] ?? 'Employee';
                    String type = data['leaveType'] ?? 'Leave';
                    String days = "${data['totalDays']} Days";

                    return _buildLeaveRequestCardPreview(name, type, days);
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 30),

            // 3. Manager Quick Actions
            const Text(
              "Management Tools",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    Icons.person_add_alt,
                    "Add Employee",
                    const Color(0xFFDFF9FB),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    Icons.assessment_outlined,
                    "Reports",
                    const Color(0xFFFFE0D3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- UI WIDGET HELPERS ---

  Widget _buildStatCard(
      String title,
      String count,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 15),
          Text(
            count,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  // New Helper: Dashboard Preview Card (No buttons, just shows info)
  Widget _buildLeaveRequestCardPreview(String name, String type, String details) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange.shade100,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'E',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "$type • $details",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String title, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFFE67E22)),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      elevation: 10,
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.orange,
      unselectedItemColor: Colors.grey.shade400,
      currentIndex: 0,
      onTap: (index) {
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ManagerDashboard()),
          );
        } else if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TeamScreen()),
          );
        } else if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CalendarScreen()),
          );
        }
        // Calendar and Settings coming next
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Overview"),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          label: "Team",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: "Calendar",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
      ],
    );
  }
}