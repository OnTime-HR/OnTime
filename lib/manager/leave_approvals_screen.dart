import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:ontime/manager/medical_claim_detail_screen.dart';
import 'package:grouped_list/grouped_list.dart';

class LeaveApprovalsScreen extends StatefulWidget {
  const LeaveApprovalsScreen({super.key});

  @override
  State<LeaveApprovalsScreen> createState() => _LeaveApprovalsScreenState();
}

class _LeaveApprovalsScreenState extends State<LeaveApprovalsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // --- MERGED STREAM FOR LEAVES AND CLAIMS ---
  Stream<List<QueryDocumentSnapshot>> _getPendingRequestsStream() {
    final String? managerId = currentUser?.uid;
    if (managerId == null) return const Stream.empty();

    // Stream 1: Leaves
    Stream<List<QueryDocumentSnapshot>> leaves = FirebaseFirestore.instance
        .collection('leave_requests')
        .where('approverId', isEqualTo: managerId)
        .where('status', isEqualTo: 'Pending')
        .snapshots()
        .map((s) => s.docs);

    // Stream 2: Claims
    Stream<List<QueryDocumentSnapshot>> claims = FirebaseFirestore.instance
        .collection('medical_claims')
        .where('approverId', isEqualTo: managerId)
        .where('status', isEqualTo: 'Pending')
        .snapshots()
        .map((s) => s.docs);

    return Rx.combineLatest2(leaves, claims, (List<QueryDocumentSnapshot> l, List<QueryDocumentSnapshot> c) {
      List<QueryDocumentSnapshot> combined = [...l, ...c];
      combined.sort((a, b) {
        Timestamp tA = (a.data() as Map)['appliedAt'] ?? (a.data() as Map)['submittedAt'] ?? Timestamp.now();
        Timestamp tB = (b.data() as Map)['appliedAt'] ?? (b.data() as Map)['submittedAt'] ?? Timestamp.now();
        return tB.compareTo(tA);
      });
      return combined;
    });
  }


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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text("Pending Approvals", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: _getPendingRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFF39C12)));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("No pending requests.", style: TextStyle(color: Colors.grey.shade500)));
          }

          return GroupedListView<QueryDocumentSnapshot, String>(
            elements: snapshot.data!,
            groupBy: (doc) {
              Timestamp ts = (doc.data() as Map)['appliedAt'] ?? (doc.data() as Map)['submittedAt'] ?? Timestamp.now();
              DateTime date = ts.toDate();
              DateTime today = DateTime.now();
              if (_isSameDay(date, today)) return "Today";
              if (_isSameDay(date, today.subtract(const Duration(days: 1)))) return "Yesterday";
              return DateFormat('MMM dd, yyyy').format(date);
            },
            groupSeparatorBuilder: (String value) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
            ),
            itemBuilder: (context, doc) {
              final data = doc.data() as Map<String, dynamic>;
              bool isLeave = data.containsKey('leaveType');
              String name = data['userName'] ?? 'Employee';
              String type = isLeave ? data['leaveType'] : (data['claimType'] ?? 'Medical Claim');
              var rawAmount = data['claimAmount'] ?? data['amount'];
              String details = isLeave ? "${data['totalDays'] ?? '?'} Days" : (rawAmount != null ? "Amount: LKR $rawAmount" : "Awaiting Review");

              return _buildRequestCardPreview(name, type, details, isLeave, onTap: () {
                if (isLeave) {
                  _showLeaveDetailDialog(context, doc);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MedicalClaimDetailScreen(claimDoc: doc)));
                }
              });
            },
            order: GroupedListOrder.DESC,
          );
        },
      ),
    );
  }

  // --- ADDED THIS MISSING WIDGET ---
  Widget _buildRequestCardPreview(String name, String type, String details, bool isLeave, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isLeave ? const Color(0xFFFFF8ED) : Colors.teal.shade50,
              child: Text(name[0].toUpperCase(), style: TextStyle(color: isLeave ? const Color(0xFFF39C12) : Colors.teal, fontWeight: FontWeight.bold)),
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
      ),
    );
  }
}