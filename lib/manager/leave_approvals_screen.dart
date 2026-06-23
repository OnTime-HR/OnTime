import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class LeaveApprovalsScreen extends StatefulWidget {
  const LeaveApprovalsScreen({super.key});

  @override
  State<LeaveApprovalsScreen> createState() => _LeaveApprovalsScreenState();
}

class _LeaveApprovalsScreenState extends State<LeaveApprovalsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // --- REUSABLE POPUP MESSENGER ---
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
                    style: TextStyle(color: isError ? Colors.red : Colors.green, fontWeight: FontWeight.bold)
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

  // --- LEAVE REQUEST DETAIL & ACTION METHODS ---
  void _showLeaveDetailDialog(BuildContext context, DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String docId = doc.id;
    String employeeId = data['userId'] ?? '';
    String employeeName = data['userName'] ?? 'Employee';
    String leaveType = data['leaveType'] ?? 'Leave';
    String reason = data['reason'] ?? 'No reason provided.';
    String totalDays = "${data['totalDays']} Days";

    // Formatting the dates
    DateTime? startDate = (data['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate = (data['endDate'] as Timestamp?)?.toDate();
    String dateRange = (startDate != null && endDate != null)
        ? "${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}"
        : "Dates not specified";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFFFFF8ED), shape: BoxShape.circle),
              child: const Icon(Icons.event_available, color: Color(0xFFF39C12)),
            ),
            const SizedBox(width: 10),
            const Text("Leave Request", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(employeeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.category, "Type", leaveType),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.calendar_month, "Dates", dateRange),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.timelapse, "Duration", totalDays),
            const Divider(height: 24),
            const Text("Reason:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(reason, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
          ],
        ),
        actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _confirmRejection(context, docId, employeeId, employeeName, leaveType),
                  child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _confirmApproval(context, docId, employeeId, employeeName, leaveType),
                  child: const Text("Approve", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // Helper for the detail dialog rows
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              children: [
                TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirmApproval(BuildContext parentContext, String docId, String employeeId, String employeeName, String leaveType) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Confirm Approval", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        content: Text("Are you sure you want to approve this $leaveType for $employeeName?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('leave_requests').doc(docId).update({'status': 'Approved'});

              await FirebaseFirestore.instance.collection('users').doc(employeeId).collection('notifications').add({
                'title': 'Leave Approved',
                'body': 'Your $leaveType request has been approved.',
                'type': 'system',
                'isRead': false,
                'timestamp': FieldValue.serverTimestamp(),
              });

              if (ctx.mounted) Navigator.pop(ctx);
              if (parentContext.mounted) Navigator.pop(parentContext);

              _showPopupMessage("Approved", "Leave request has been approved.", isError: false);
            },
            child: const Text("Yes, Approve", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmRejection(BuildContext parentContext, String docId, String employeeId, String employeeName, String leaveType) {
    TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Reject Request", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Please provide a reason for rejecting this request from $employeeName.", style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                  hintText: "Reason for rejection...",
                  filled: true,
                  fillColor: Colors.red.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {

              // --- NEW: STACKED ERROR POPUP ---
              if (reasonController.text.trim().isEmpty) {
                showDialog(
                  context: ctx,
                  builder: (errorCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red),
                        SizedBox(width: 10),
                        Text("Reason Required", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    content: const Text("Please type a reason before confirming the rejection so the employee knows why it was denied."),
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.pop(errorCtx),
                        child: const Text("OK", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                return; // Stops the submission process
              }
              // --------------------------------

              await FirebaseFirestore.instance.collection('leave_requests').doc(docId).update({
                'status': 'Rejected',
                'rejectionReason': reasonController.text.trim(),
              });

              await FirebaseFirestore.instance.collection('users').doc(employeeId).collection('notifications').add({
                'title': 'Leave Rejected',
                'body': 'Your $leaveType request was rejected. Reason: ${reasonController.text.trim()}',
                'type': 'system',
                'isRead': false,
                'timestamp': FieldValue.serverTimestamp(),
              });

              if (ctx.mounted) Navigator.pop(ctx);
              if (parentContext.mounted) Navigator.pop(parentContext);

              _showPopupMessage("Rejected", "Leave request has been rejected.", isError: true);
            },
            child: const Text("Confirm Reject", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Please log in.")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Pending Approvals",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Fetch all pending leave requests assigned to this manager
        stream: FirebaseFirestore.instance
            .collection('leave_requests')
            .where('approverId', isEqualTo: currentUser!.uid)
            .where('status', isEqualTo: 'Pending')
            .orderBy('appliedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFF39C12)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200)
                    ),
                    child: Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 24),
                  const Text("You're all caught up!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text("No pending requests to review.", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                ],
              ),
            );
          }

          final pendingRequests = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: pendingRequests.length,
            itemBuilder: (context, index) {
              final doc = pendingRequests[index];
              final data = doc.data() as Map<String, dynamic>;

              final String name = data['userName'] ?? 'Employee';
              final String leaveType = data['leaveType'] ?? 'Leave';
              final String totalDays = "${data['totalDays']} Days";

              return GestureDetector(
                onTap: () => _showLeaveDetailDialog(context, doc), // Opens the detailed popup!
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFFFF8ED),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'E',
                          style: const TextStyle(color: Color(0xFFF39C12), fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                            const SizedBox(height: 4),
                            Text("$leaveType • $totalDays", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20)
                        ),
                        child: const Text("Review", style: TextStyle(color: Color(0xFFF39C12), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}