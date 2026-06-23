import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  String? selectedLeaveType;
  DateTimeRange? selectedDateRange;
  final TextEditingController _reasonController = TextEditingController();

  bool isLoading = false; // <-- Tracks loading state

  final List<String> leaveTypes = [
    'Sick Leave',
    'Personal Leave',
    'Official Leave',
    'Maternity/Paternity Leave'
  ];

  // Calculate total days selected
  int get totalDays {
    if (selectedDateRange == null) return 0;
    // Add 1 to include both the start and end day
    return selectedDateRange!.end.difference(selectedDateRange!.start).inDays + 1;
  }

  // Open native date range picker
  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF5A623), // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Body text color
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDateRange = picked;
      });
    }
  }

  // --- SMART UNIFIED POPUP MESSAGE ---
  void _showPopupMessage(String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      barrierDismissible: false, // Forces the user to tap OK
      builder: (BuildContext dialogContext) {
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
                  ),
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
              onPressed: () {
                Navigator.of(dialogContext).pop(); // 1. Always close the dialog

                if (!isError) {
                  Navigator.of(context).pop(); // 2. Return to dashboard only on SUCCESS
                }
              },
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- FIREBASE SUBMISSION LOGIC ---
  Future<void> _submitLeaveRequest() async {
    // 1. Validate fields
    if (selectedLeaveType == null || selectedDateRange == null || _reasonController.text.isEmpty) {
      _showPopupMessage("Missing Fields", "Please fill all fields before submitting.", isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // 2. Fetch the user's profile
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final String role = userData['role'] ?? 'Employee';
      final String userName = userData['name'] ?? 'Unknown User';

      // 3. Get the manager's ID
      final String assignedManagerId = userData['managerId'] ?? 'unassigned';

      // 4. Determine who needs to approve this
      String approverId = (role == 'Manager') ? 'admin' : assignedManagerId;

      // 5. Save to Firestore
      final leaveDoc = await FirebaseFirestore.instance.collection('leave_requests').add({
        'userId': user.uid,
        'userName': userName,
        'userRole': role,
        'approverId': approverId,
        'leaveType': selectedLeaveType,
        'startDate': selectedDateRange!.start,
        'endDate': selectedDateRange!.end,
        'totalDays': totalDays,
        'reason': _reasonController.text.trim(),
        'status': 'Pending',
        'appliedAt': FieldValue.serverTimestamp(),
      });

      // 5.5 Send Notification to the Approver
      if (approverId != 'unassigned') {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(approverId)
            .collection('notifications')
            .add({
          'title': 'New Leave Request',
          'body': '$userName has requested $selectedLeaveType.',
          'type': 'leave_request',
          'leaveRequestId': leaveDoc.id,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // 6. Success Block
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        _showPopupMessage(
            "Success!",
            "Your leave request has been successfully submitted for approval."
        );
      }
    } catch (e) {
      // 7. Error Block
      if (mounted) {
        _showPopupMessage(
            "Error",
            "Error submitting request: $e",
            isError: true
        );
      }
    } finally {
      // 8. Cleanup Block
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Apply Leave",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. BALANCE CARDS
            Row(
              children: [
                Expanded(
                  child: _buildBalanceCard(
                    "Annual Balance",
                    "12 Days",
                    const Color(0xFFFFF8ED),
                    const Color(0xFFF5A623),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildBalanceCard(
                    "Sick Balance",
                    "5 Days",
                    const Color(0xFFF8F9FB),
                    Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // 2. LEAVE TYPE DROPDOWN
            const Text("Leave Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedLeaveType,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Color(0xFFF5A623), width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFFF8F9FB),
              ),
              hint: const Text("Select leave type"),
              icon: const Icon(Icons.keyboard_arrow_down),
              items: leaveTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) => setState(() => selectedLeaveType = value),
            ),
            const SizedBox(height: 30),

            // 3. DATE SELECTION
            const Text("Select Dates", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Color(0xFFF5A623)),
                        const SizedBox(width: 10),
                        Text(
                          selectedDateRange == null
                              ? "Tap to select date range"
                              : "${selectedDateRange!.start.day}/${selectedDateRange!.start.month} - ${selectedDateRange!.end.day}/${selectedDateRange!.end.month}",
                          style: TextStyle(
                            fontSize: 16,
                            color: selectedDateRange == null ? Colors.grey : Colors.black,
                            fontWeight: selectedDateRange == null ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // TOTAL DAYS COUNTER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total days selected:", style: TextStyle(color: Colors.grey, fontSize: 14)),
                Text("$totalDays Days", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 30),

            // 4. REASON TEXT AREA
            const Text("Reason", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Please describe why you are requesting leave...",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Color(0xFFF5A623), width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFFF8F9FB),
              ),
            ),
            const SizedBox(height: 40),

            // 5. SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submitLeaveRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5A623),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 5,
                  shadowColor: const Color(0xFFF5A623).withOpacity(0.5),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "Submit Request",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for the top balance cards
  Widget _buildBalanceCard(String title, String days, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(days, style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}