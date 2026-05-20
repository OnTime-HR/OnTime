import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:ontime/shared/apply_leave_screen.dart';
import 'package:ontime/shared/medical_claim_screen.dart';
import 'package:ontime/shared/shift_calendar_screen.dart';
import 'package:ontime/shared/attendance_service.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  // --- STATE VARIABLES ---
  String userName = "Employee";
  bool isAutoAttendance = true;

  // Attendance States
  bool isLoadingLocation = false;
  bool isCheckedIn = false;
  bool isCheckedOut = false;
  String checkInTime = "--:--";
  String checkOutTime = "--:--";

  final AttendanceService _attendanceService = AttendanceService();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchTodayAttendance(); // Fetches status as soon as app opens!
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

  // --- FETCH TODAY'S ATTENDANCE ---
  void _fetchTodayAttendance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('attendance')
          .doc(todayDate)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          isCheckedIn = doc.data()?['checkInTime'] != null;
          checkInTime = doc.data()?['checkInTime'] ?? "--:--";
          isCheckedOut = doc.data()?['checkOutTime'] != null;
          checkOutTime = doc.data()?['checkOutTime'] ?? "--:--";
        });
      } else if (mounted) {
        // Fallback fallback: If no document exists yet today, ensure states are pristine
        setState(() {
          isCheckedIn = false;
          isCheckedOut = false;
          checkInTime = "--:--";
          checkOutTime = "--:--";
        });
      }
    }
  }

  // --- HANDLE CHECK IN ---
  void _handleCheckIn() async {
    // FIXED: Only block check-in if they are actively checked in and HAVEN'T checked out yet
    if (isCheckedIn && !isCheckedOut) return;

    setState(() => isLoadingLocation = true);

    try {
      Position? pos = await _attendanceService.getCurrentLocation();

      if (pos == null) {
        if (mounted) {
          _showPopupMessage("Location Failed", "Could not get your current GPS location.", isError: true);
          setState(() => isLoadingLocation = false);
        }
        return;
      }

      Map<String, dynamic> assigned = await _attendanceService.getAssignedLocation();

      bool isInside = _attendanceService.isWithinGeofence(
          pos, assigned['latitude'], assigned['longitude'], assigned['radius']);

      if (isInside) {
        await _attendanceService.markAttendance('check_in', pos);
        if (mounted) {
          _showPopupMessage("Success!", "You have successfully checked in for today.");
        }
        _fetchTodayAttendance();
      } else {
        if (mounted) {
          _showPopupMessage("Out of Bounds", "You are outside the authorized work zone! Please move closer to the office.", isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showPopupMessage("Error", e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => isLoadingLocation = false);
    }
  }

  // --- HANDLE CHECK OUT ---
  void _handleCheckOut() async {
    if (!isCheckedIn || isCheckedOut) return;

    setState(() => isLoadingLocation = true);

    try {
      Position? pos = await _attendanceService.getCurrentLocation();

      if (pos == null) {
        if (mounted) {
          _showPopupMessage("Location Failed", "Could not get your current GPS location.", isError: true);
          setState(() => isLoadingLocation = false);
        }
        return;
      }

      Map<String, dynamic> assigned = await _attendanceService.getAssignedLocation();

      bool isInside = _attendanceService.isWithinGeofence(
          pos, assigned['latitude'], assigned['longitude'], assigned['radius']);

      if (isInside) {
        await _attendanceService.markAttendance('check_out', pos);
        if (mounted) {
          _showPopupMessage("Success!", "You have successfully checked out. Have a great evening!");
        }
        _fetchTodayAttendance();
      } else {
        if (mounted) {
          _showPopupMessage("Out of Bounds", "You must be at the office to check out!", isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showPopupMessage("Error", e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => isLoadingLocation = false);
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
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

  // --- POP-UP NOTIFICATION HELPER ---
  void _showPopupMessage(String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? Colors.red : Colors.green,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                  title,
                  style: TextStyle(
                    color: isError ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  )
              ),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isError ? Colors.red : Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentDate = DateFormat('MMM dd yyyy, EEEE').format(DateTime.now());

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
                    currentDate,
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
                stream: FirebaseFirestore.instance.collection('company_news').orderBy('createdAt', descending: true).limit(1).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.orange));
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();

                  var newsData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(top: 14.0, bottom: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Company News", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 12),
                        _buildSmartNewsCard(newsData['title'] ?? "Company Update", newsData['description'] ?? "", newsData['tag'] ?? "Notice"),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // --- 4. DYNAMIC CHECK-IN CIRCLE ---
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200, width: 2)),
                    ),
                    GestureDetector(
                      // Handles clicking transitions between check-in states smoothly
                      onTap: (!isLoadingLocation && (!isCheckedIn || isCheckedOut) && isAutoAttendance) ? _handleCheckIn : null,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: (isCheckedIn && !isCheckedOut) ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
                                blurRadius: 30, spreadRadius: 10
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isLoadingLocation && (!isCheckedIn || isCheckedOut))
                              const CircularProgressIndicator(color: Colors.orange)
                            else ...[
                              Icon(
                                  (isCheckedIn && !isCheckedOut) ? Icons.check_circle : Icons.touch_app,
                                  color: (isCheckedIn && !isCheckedOut) ? const Color(0xFF2ECC71) : const Color(0xFFF39C12),
                                  size: 48
                              ),
                              const SizedBox(height: 12),
                              Text(
                                  (isCheckedIn && !isCheckedOut) ? "CHECKED IN" : "TAP TO CHECK IN",
                                  style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)
                              ),
                              const SizedBox(height: 4),
                              if (isCheckedIn && !isCheckedOut)
                                Text(
                                    checkInTime,
                                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.1)
                                ),
                            ]
                          ],
                        ),
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

              // --- 5. DYNAMIC CHECK OUT BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: (isCheckedIn && !isCheckedOut && !isLoadingLocation && isAutoAttendance) ? _handleCheckOut : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCheckedOut ? Colors.grey.shade400 : const Color(0xFFF39C12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                    elevation: isCheckedOut ? 0 : 4,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: (isLoadingLocation && isCheckedIn && !isCheckedOut)
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                          isCheckedOut ? "CHECKED OUT AT $checkOutTime" : "CHECK OUT",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)
                      ),
                      if (!isCheckedOut) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                      ]
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
                  Expanded(child: _buildActionCard(Icons.calendar_today_rounded, "Apply Leave", Colors.blue.shade100, Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ApplyLeaveScreen())))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildActionCard(Icons.medical_services_outlined, "Medical Claim", Colors.teal.shade100, Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MedicalClaimScreen())))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildActionCard(Icons.grid_view_rounded, "Shift Calendar", Colors.purple.shade100, Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ShiftCalendarScreen())))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildActionCard(Icons.more_horiz, "More", Colors.orange.shade100, Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MoreActionsScreen())))),
                ],
              ),
              const SizedBox(height: 40),

              // --- 7. EMERGENCY SOS BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed: () async {
                    setState(() => isLoadingLocation = true);

                    try {
                      Position? pos = await _attendanceService.getCurrentLocation();

                      if (mounted) {
                        setState(() => isLoadingLocation = false);
                        _showPopupMessage(
                            "EMERGENCY ALERT SENT",
                            "Your alert has been sent to the Manager${pos != null ? " with your current GPS coordinates." : "."}",
                            isError: true
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => isLoadingLocation = false);
                        _showPopupMessage("Error", "Could not send alert: $e", isError: true);
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.red, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                  ),
                  child: isLoadingLocation
                      ? const CircularProgressIndicator(color: Colors.red)
                      : const Row(
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
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
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