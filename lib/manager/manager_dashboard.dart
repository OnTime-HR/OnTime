import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:ontime/main.dart';
import 'package:ontime/manager/manager_notification_screen.dart';
import 'package:ontime/manager/leave_approvals_screen.dart';
import 'package:ontime/shared/apply_leave_screen.dart';
import 'package:ontime/shared/medical_claim_screen.dart';
import 'package:ontime/shared/attendance_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ontime/manager/team_shift_screen.dart';
import 'package:ontime/manager/assign_location_screen.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  // --- STATE VARIABLES ---
  String managerName = "Manager";
  bool isAutoAttendance = false;

  // Attendance States
  bool isLoadingLocation = false;
  bool isCheckedIn = false;
  bool isCheckedOut = false;
  String checkInTime = "--:--";
  String checkOutTime = "--:--";
  String? totalWorkingTime;

  final AttendanceService _attendanceService = AttendanceService();

  @override
  void initState() {
    super.initState();
    _fetchManagerData();
    _fetchTodayAttendance();
    _loadAutoPreference();
  }

  // --- NEW: LOAD PREFERENCE FROM MEMORY ---
  void _loadAutoPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool savedPreference = prefs.getBool('auto_attendance_enabled') ?? false;

    if (mounted) {
      setState(() {
        isAutoAttendance = savedPreference;
      });
    }

    if (savedPreference) {
      _attendanceService.startAutoAttendance();
    }
  }

  // --- NEW: SAVE PREFERENCE TO MEMORY ---
  void _toggleAutoAttendance(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_attendance_enabled', value);

    setState(() => isAutoAttendance = value);

    if (value) {
      _attendanceService.startAutoAttendance();
      _showPopupMessage("Auto-Attendance Enabled", "Your location will be monitored to check you in and out automatically.");
    } else {
      _attendanceService.stopAutoAttendance();
      _showPopupMessage("Auto-Attendance Disabled", "You must manually tap the buttons to check in and out.");
    }
  }


  void _fetchManagerData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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

  // --- FETCH TODAY's ATTENDANCE ---
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
          totalWorkingTime = doc.data()?['totalWorkingTime'];
        });
      } else if (mounted) {
        setState(() {
          isCheckedIn = false;
          isCheckedOut = false;
          checkInTime = "--:--";
          checkOutTime = "--:--";
          totalWorkingTime = null;
        });
      }
    }
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
              Expanded(
                child: Text(
                    title,
                    style: TextStyle(
                      color: isError ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    )
                ),
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

  // --- HANDLE CHECK IN ---
  void _handleCheckIn() async {
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
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
                      "Hello, $managerName 👋",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagerNotificationScreen()));
                        },
                        icon: const Badge(
                          backgroundColor: Colors.redAccent,
                          child: Icon(Icons.notifications_none_rounded, color: Colors.black87, size: 28),
                        ),
                      ),
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

              // --- 2. DATE AND SWITCH ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      currentDate,
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Auto", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                      Switch(
                        value: isAutoAttendance,
                        onChanged: _toggleAutoAttendance,
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
                      onTap: (!isLoadingLocation && (!isCheckedIn || isCheckedOut)) ? _handleCheckIn : null,
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

              // --- WORKING HOURS / TOTAL TIME DISPLAY ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: totalWorkingTime != null ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  totalWorkingTime != null
                      ? "🎉 Shift Completed!\nTotal Time: $totalWorkingTime"
                      : "Standard Hours: 08:30 AM - 05:30 PM",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: totalWorkingTime != null ? Colors.green.shade700 : Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // --- 5. DYNAMIC CHECK OUT BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: (isCheckedIn && !isCheckedOut && !isLoadingLocation) ? _handleCheckOut : null,
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
              const SizedBox(height: 40),

              // --- 6. TEAM STATS ---
              const Text("Today's Team Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildStatCard("Present", "42", Icons.people_outline, Colors.blue.shade100, Colors.blue)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard("On Leave", "3", Icons.event_busy, Colors.orange.shade100, Colors.orange)),
                ],
              ),
              const SizedBox(height: 40),

              // --- 7. PENDING APPROVALS ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Pending Approvals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaveApprovalsScreen()));
                    },
                    child: const Text("View All", style: TextStyle(color: Color(0xFFF39C12), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('leave_requests')
                    .where('approverId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    .where('status', isEqualTo: 'Pending')
                    .orderBy('appliedAt', descending: true)
                    .limit(2)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Colors.orange)));
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                      child: const Text("No pending requests right now. Great job! 🎉", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                    );
                  }

                  return Column(
                    children: snapshot.data!.docs.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      return _buildLeaveRequestCardPreview(
                          data['userName'] ?? 'Employee',
                          data['leaveType'] ?? 'Leave',
                          "${data['totalDays']} Days"
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 40),

              // --- 8. MANAGEMENT TOOLS ---
              const Text("Management Tools", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                        Icons.calendar_month_rounded,
                        "Shift Schedule",
                        Colors.purple.shade100,
                        Colors.purple,
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const TeamShiftScreen())
                          );
                        }
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                        Icons.location_on_outlined,
                        "Assign Location",
                        Colors.indigo.shade100,
                        Colors.indigo,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AssignLocationScreen()),
                          );
                        }
                    ),
                  ),
                ],
              ),
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
                        }
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
                        }
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // --- 9. EMERGENCY SOS BUTTON ---
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
                            "Your alert has been sent to the Admin${pos != null ? " with your current GPS coordinates." : "."}",
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

  // --- UI WIDGET HELPERS ---
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

  Widget _buildStatCard(String title, String count, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 16),
          Text(count, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

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
            backgroundColor: const Color(0xFFFFF8ED),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'E',
              style: const TextStyle(color: Color(0xFFF39C12), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                const SizedBox(height: 4),
                Text("$type • $details", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
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