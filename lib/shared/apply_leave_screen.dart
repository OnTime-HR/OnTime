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

  bool isLoading = false; // <-- Added loading state

  final List<String> leaveTypes = [
    'Annual Leave',
    'Sick Leave',
    'Casual Leave',
    'Maternity/Paternity Leave',
    'Unpaid Leave'
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

  // --- NEW FIREBASE SUBMISSION LOGIC ---
  Future<void> _submitLeaveRequest() async {
    // 1. Validate fields
    if (selectedLeaveType == null || selectedDateRange == null || _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields before submitting.")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // 2. Fetch the user's profile to check if they are a Manager or Employee
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final String role = userData['role'] ?? 'Employee';
      final String userName = userData['name'] ?? 'Unknown User';

      // 3. Get the manager's ID (or default to unassigned if not set)
      final String assignedManagerId = userData['managerId'] ?? 'unassigned';

      // 4. Determine who needs to approve this
      String approverId = (role == 'Manager') ? 'admin' : assignedManagerId;

      // 5. Save to Firestore
      await FirebaseFirestore.instance.collection('leave_requests').add({
        'userId': user.uid,
        'userName': userName,
        'userRole': role,
        'approverId': approverId, // Routes the request!
        'leaveType': selectedLeaveType,
        'startDate': selectedDateRange!.start,
        'endDate': selectedDateRange!.end,
        'totalDays': totalDays,
        'reason': _reasonController.text.trim(),
        'status': 'Pending', // Default status
        'appliedAt': FieldValue.serverTimestamp(),
      });

      // 6. Success! Show message and go back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Leave Request Submitted Successfully!", style: TextStyle(color: Colors.green))),
        );
        Navigator.pop(context); // Go back to dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error submitting request: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
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
                    const Color(0xFFFFF8ED), // Light orange background
                    const Color(0xFFF5A623), // Orange text
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildBalanceCard(
                    "Sick Balance",
                    "5 Days",
                    const Color(0xFFF8F9FB), // Light grey background
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
                // <-- Point to the new function here! Disable button if loading.
                onPressed: isLoading ? null : _submitLeaveRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5A623),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 5,
                  shadowColor: const Color(0xFFF5A623).withOpacity(0.5),
                ),
                // <-- Show a spinner if loading, otherwise show text
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