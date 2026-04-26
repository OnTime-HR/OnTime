import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ontime/shared/apply_leave_screen.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  // Logic state
  String userName = "Employee";
  bool isAutoAttendance = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            userName = doc.data()?['name'] ?? "User";
          });
        }
      } catch (e) {
        debugPrint("Error fetching user data: $e");
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
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) Navigator.pop(context);
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
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // --- 1. HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Hello, $userName 👋",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _showLogoutDialog,
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                      ),
                      const CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- 2. DATE & TOGGLE ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Jan 12 2026, Monday",
                    style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Row(
                    children: [
                      Text("Auto", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                      Switch(
                        value: isAutoAttendance,
                        onChanged: (val) => setState(() => isAutoAttendance = val),
                        activeColor: const Color(0xFFF39C12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // --- 3. DYNAMIC COMPANY NEWS STREAM ---
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('company_news')
                    .orderBy('createdAt', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text("Firebase Error: ${snapshot.error}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.orange));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text("No news available in the database.", style: TextStyle(color: Colors.grey)),
                    );
                  }

                  var newsData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                  String title = newsData['title'] ?? "Company Update";
                  String description = newsData['description'] ?? "Please check with your manager for details.";
                  String tag = newsData['tag'] ?? "Notice";

                  return Padding(
                    padding: const EdgeInsets.only(top: 14.0, bottom: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Company News", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 12),
                        _buildSmartNewsCard(title, description, tag),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // --- 4. CHECK-IN CIRCLE ---
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200, width: 2)),
                    ),
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.08), blurRadius: 30, spreadRadius: 10)],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 48),
                          SizedBox(height: 12),
                          Text("CHECKED IN", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          SizedBox(height: 4),
                          Text("09:41", style: TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.1)),
                          Text("AM", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: Text(
                  "Working Hours: 08:30 AM - 05:30 PM",
                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 30),

              // --- 5. CHECK OUT BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF39C12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                    elevation: 4,
                    shadowColor: Colors.orange.withOpacity(0.3),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("CHECK OUT", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      SizedBox(width: 12),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // --- 6. QUICK ACTIONS GRID ---
              const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      Icons.calendar_today_rounded,
                      "Apply Leave",
                      Colors.blue.shade100,
                      Colors.blue,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ApplyLeaveScreen()));
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      Icons.medical_services_outlined,
                      "Medical Claim",
                      Colors.teal.shade100,
                      Colors.teal,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const MedicalClaimScreen()));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16), // Spacing between rows

              // ADDED MISSING SECOND ROW BACK IN
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                        Icons.grid_view_rounded,
                        "Shift Calendar",
                        Colors.purple.shade100,
                        Colors.purple,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ShiftCalendarScreen()));
                        }
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                        Icons.more_horiz,
                        "More",
                        Colors.orange.shade100,
                        Colors.orange,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const MoreActionsScreen()));
                        }
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // --- 7. SOS BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Emergency Alert Sent!')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.red, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red),
                      SizedBox(width: 12),
                      Text("EMERGENCY SOS", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.2)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildSmartNewsCard(String title, String description, String tag) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF39C12), Color(0xFFF1C40F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.campaign, color: Colors.white, size: 24)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(20)), child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 15),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String title, Color bgColor, Color iconColor, {VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () {
        if (onTap != null) {
          onTap();
        } else if (title == "Shift Calendar") {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Use the "Schedule" tab at the bottom to view your shifts!')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- PLACEHOLDER SCREENS (Added so the buttons don't crash the app) ---

class MedicalClaimScreen extends StatelessWidget {
  const MedicalClaimScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Medical Claim"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: const Center(child: Text("Medical Claim UI goes here")),
    );
  }
}

class ShiftCalendarScreen extends StatelessWidget {
  const ShiftCalendarScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Shift Calendar"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: const Center(child: Text("Shift Calendar UI goes here")),
    );
  }
}

class MoreActionsScreen extends StatelessWidget {
  const MoreActionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("More Actions"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: const Center(child: Text("More Actions UI goes here")),
    );
  }
}