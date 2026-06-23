import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:ontime/shared/apply_leave_screen.dart';
import 'package:ontime/shared/medical_claim_screen.dart';
import 'package:ontime/shared/attendance_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ontime/services/emergency_service.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  // --- STATE VARIABLES ---
  String userName = "Employee";
  bool isAutoAttendance = false;

  String shiftStartTime = "08:30 AM"; // Default
  String shiftEndTime = "05:30 PM";   // Default

  // Profile Image State
  String? profileImageUrl;

  // Attendance States
  bool isLoadingLocation = false;
  bool isCheckedIn = false;
  bool isCheckedOut = false;
  String checkInTime = "--:--";
  String checkOutTime = "--:--";
  String? totalWorkingTime;

  // --- NEW: CAROUSEL VARIABLES ---
  final PageController _newsPageController = PageController();
  int _currentNewsIndex = 0;

  final AttendanceService _attendanceService = AttendanceService();
  final EmergencyService _emergencyService = EmergencyService();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchTodayAttendance();
    _loadAutoPreference();
  }

  @override
  void dispose() {
    _newsPageController.dispose(); // Prevent memory leaks
    super.dispose();
  }

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

  void _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && mounted) {
          setState(() {
            userName = userDoc.data()?['name'] ?? "User";
            profileImageUrl = userDoc.data()?['profileImageUrl'];
          });

          String? shiftId = userDoc.data()?['assignedShiftId'];
          if (shiftId != null) {
            var shiftDoc = await FirebaseFirestore.instance.collection('shifts').doc(shiftId).get();
            if (shiftDoc.exists && mounted) {
              setState(() {
                shiftStartTime = shiftDoc.data()?['startTime'] ?? "08:30 AM";
                shiftEndTime = shiftDoc.data()?['endTime'] ?? "05:30 PM";
              });
            }
          }
        }
      } catch (e) {
        debugPrint("Error fetching user data: $e");
      }
    }
  }

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

  void _showEmergencySOSDialog() {
    final TextEditingController reasonController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.redAccent, width: 2),
              ),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                  SizedBox(width: 10),
                  Text(
                    "Emergency SOS",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "You are about to trigger an emergency alert. This will instantly notify Management.",
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: "Briefly state the reason (e.g., Medical, Accident)",
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      filled: true,
                      fillColor: Colors.red.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    if (reasonController.text.trim().isEmpty) {
                      showDialog(
                        context: dialogContext,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red),
                              SizedBox(width: 10),
                              Text("Reason Required", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          content: const Text("Please enter a brief reason for the emergency before confirming."),
                          actions: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("OK", style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    setDialogState(() { isSubmitting = true; });

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await _emergencyService.triggerEmergencySOS(
                          userId: user.uid,
                          userName: userName,
                          userRole: 'Employee',
                          reason: reasonController.text.trim(),
                        );

                        bool didCheckOut = false;
                        if (isCheckedIn && !isCheckedOut) {
                          Position? pos = await _attendanceService.getCurrentLocation();
                          if (pos != null) {
                            await _attendanceService.markAttendance('check_out', pos);
                            didCheckOut = true;
                          }
                        }

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          _fetchTodayAttendance();
                          String successMsg = didCheckOut
                              ? "Your alert has been sent, and you have been safely checked out."
                              : "Your emergency alert has been sent to Management. Please stay safe.";

                          _showPopupMessage(
                              "Emergency Sent",
                              successMsg,
                              isError: true
                          );
                        }
                      }
                    } catch (e) {
                      setDialogState(() { isSubmitting = false; });
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        _showPopupMessage("Error", "Failed to send alert: $e", isError: true);
                      }
                    }
                  },
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Confirm & Checkout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
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
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.orange.shade50,
                    backgroundImage: profileImageUrl != null
                        ? NetworkImage(profileImageUrl!)
                        : null,
                    child: profileImageUrl == null
                        ? Icon(Icons.person, color: Colors.orange.shade200)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- 2. DATE AND SWITCH ---
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
                        onChanged: _toggleAutoAttendance,
                        activeColor: const Color(0xFFF39C12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // --- 3. DYNAMIC COMPANY NEWS STREAM (ACTIVE ONLY) ---
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('company_news')
                    .where('status', isEqualTo: 'Active') // <-- NEW: Filters for active news
                    .orderBy('createdAt', descending: true) // <-- Keeps newest first
                // Removed .limit() to fetch ALL active news!
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.orange));
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();

                  final newsDocs = snapshot.data!.docs;

                  return Padding(
                    padding: const EdgeInsets.only(top: 14.0, bottom: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Company News", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 12),

                        // Swipeable PageView
                        SizedBox(
                          height: 190,
                          child: PageView.builder(
                            controller: _newsPageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentNewsIndex = index;
                              });
                            },
                            itemCount: newsDocs.length,
                            itemBuilder: (context, index) {
                              var newsData = newsDocs[index].data() as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                child: _buildSmartNewsCard(
                                  newsData['title'] ?? "Company Update",
                                  newsData['description'] ?? "",
                                  newsData['tag'] ?? "Notice",
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Animated Dot Indicators (Uses Wrap to prevent overflow if there are many active news items)
                        if (newsDocs.length > 1)
                          SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              runSpacing: 8,
                              children: List.generate(
                                newsDocs.length,
                                    (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  height: 8,
                                  width: _currentNewsIndex == index ? 24 : 8,
                                  decoration: BoxDecoration(
                                    color: _currentNewsIndex == index ? const Color(0xFFF39C12) : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

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
                      : "Assigned Hours: $shiftStartTime - $shiftEndTime",
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


              // --- 7. EMERGENCY SOS BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed: _showEmergencySOSDialog,
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
        mainAxisSize: MainAxisSize.min,
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
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          // Added maxLines to prevent overflow inside the fixed PageView height
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
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