import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  // Logic state
  String userName = "Employee";
  bool isCheckedIn = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Fetch the logged-in user's data from Firestore
  void _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            // Make sure the field 'name' exists in your Firestore 'users' collection
            userName = doc.data()?['name'] ?? "User";
          });
        }
      } catch (e) {
        debugPrint("Error fetching user data: $e");
      }
    }
  }

  // Logout confirmation dialog
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want to log out?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  // Note: AuthGate in main.dart will automatically handle navigation to Login
                }
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // --- UPDATED HEADER WITH LOGOUT ---
              Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=a'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Hello, $userName",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _showLogoutDialog,
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    tooltip: 'Logout',
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Section: Company News
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Company News", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {},
                    child: const Text("View All", style: TextStyle(color: Colors.orange)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildNewsCard(),

              const SizedBox(height: 40),

              // Circular Progress Area
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200, width: 1),
                      ),
                    ),
                    Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 10,
                          )
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 40),
                          SizedBox(height: 8),
                          Text("CHECKED IN", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.1)),
                          Text("09:41", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                          Text("AM", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Center(
                child: Text("Shift ends at 05:00 PM", style: TextStyle(color: Color(0xFF7F8C8D))),
              ),

              const SizedBox(height: 40),

              // Check Out Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF39C12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                    elevation: 5,
                    shadowColor: Colors.orange.withOpacity(0.4),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("CHECK OUT", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(width: 12),
                      Icon(Icons.arrow_forward, color: Colors.white),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Quick Actions
              Row(
                children: [
                  Expanded(child: _buildActionCard(Icons.flight_takeoff, "Apply Leave", const Color(0xFFFFE0D3))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildActionCard(Icons.local_hospital_outlined, "Medical Claim", const Color(0xFFDFF9FB))),
                ],
              ),

              const SizedBox(height: 30),

              // SOS Emergency Button
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(color: Colors.red, width: 1.5),
                ),
                child: const Center(
                  child: Text(
                    "SOS  EMERGENCY SOS",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildNewsCard() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF39C12), Color(0xFFF1C40F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.campaign, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 15),
          const Text("New Safety Protocols", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("Updated guidelines for warehouse operations...", style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
                child: const Text("Urgent", style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const Text("2h ago", style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String title, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFFE67E22)),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      elevation: 0,
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.orange,
      unselectedItemColor: Colors.grey.shade400,
      currentIndex: 0,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: "Notification"),
        BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "Schedule"),
        BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: "More"),
      ],
    );
  }
}