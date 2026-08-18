import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ontime/manager/leave_approvals_screen.dart';
import 'package:ontime/manager/medical_claim_detail_screen.dart';

class ManagerNotificationScreen extends StatefulWidget {
  const ManagerNotificationScreen({super.key});

  @override
  State<ManagerNotificationScreen> createState() => _ManagerNotificationScreenState();
}

class _ManagerNotificationScreenState extends State<ManagerNotificationScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  IconData _getIconForType(String type) {
    switch (type) {
      case 'emergency':
        return Icons.warning_rounded;
      case 'leave_request':
        return Icons.event_available_rounded;
      case 'medical_claim':
        return Icons.receipt_long_rounded;
      case 'admin_alert':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inDays > 1) return '${diff.inDays} days ago';
    if (diff.inDays == 1) return '1 day ago';
    if (diff.inHours > 1) return '${diff.inHours} hours ago';
    if (diff.inHours == 1) return '1 hour ago';
    if (diff.inMinutes > 1) return '${diff.inMinutes} mins ago';
    return 'Just now';
  }

  String _getExactTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return "${_getMonth(date.month)} ${date.day}, ${date.year} at ${TimeOfDay.fromDateTime(date).format(context)}";
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  // --- HELPER TO GROUP BY DATE ---
  String _getGroupDateString(Timestamp? timestamp) {
    if (timestamp == null) return 'OLDER';
    final date = timestamp.toDate();
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) return 'TODAY';
    if (targetDate == yesterday) return 'YESTERDAY';

    return DateFormat('MMM dd, yyyy').format(date).toUpperCase();
  }

  Future<void> _markAsRead(String docId) async {
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('notifications')
          .doc(docId)
          .set({'isRead': true}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Failed to mark notification as read: $e");
    }
  }

  Future<void> _markAllAsRead() async {
    if (currentUser == null) return;
    final unreadDocs = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    if (unreadDocs.docs.isEmpty) return;

    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in unreadDocs.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  void _showPopupMessage(String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: isError ? Colors.red : Colors.green, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TextStyle(color: isError ? Colors.red : Colors.green, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isError ? Colors.red : Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showLeaveDetailDialog(BuildContext context, DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String docId = doc.id;
    String employeeId = data['userId'] ?? '';
    String employeeName = data['userName'] ?? 'Employee';
    String leaveType = data['leaveType'] ?? 'Leave';
    String reason = data['reason'] ?? 'No reason provided.';
    String totalDays = "${data['totalDays']} Days";

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
            Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Color(0xFFFFF8ED), shape: BoxShape.circle), child: const Icon(Icons.event_available, color: Color(0xFFF39C12))),
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
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _confirmRejection(context, docId, employeeId, employeeName, leaveType),
                  child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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

              // --- STACKED ERROR POPUP ---
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

  void _showNotificationDetails(BuildContext context, String title, String body, Timestamp? timestamp, String type) {
    final bool isEmergency = type == 'emergency';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isEmergency ? Colors.redAccent : Colors.transparent, width: isEmergency ? 2 : 0),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: isEmergency ? Colors.red.shade50 : Colors.orange.shade50, shape: BoxShape.circle),
              child: Icon(_getIconForType(type), color: isEmergency ? Colors.red : const Color(0xFFF39C12), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isEmergency ? Colors.red.shade800 : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(_getExactTime(timestamp), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        content: Text(body, style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text("Manager Inbox", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(onPressed: _markAllAsRead, child: const Text("Mark all read", style: TextStyle(color: Color(0xFFF39C12), fontWeight: FontWeight.bold))),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).collection('notifications').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFF39C12)));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

          final notifications = snapshot.data!.docs.toList();
          notifications.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final Timestamp? timeA = dataA['timestamp'] ?? dataA['createdAt'];
            final Timestamp? timeB = dataB['timestamp'] ?? dataB['createdAt'];
            if (timeA == null) return 1;
            if (timeB == null) return -1;
            return timeB.compareTo(timeA);
          });

          // --- DYNAMIC LIST GENERATION WITH DATE HEADERS ---
          List<Widget> listItems = [];
          String? currentGroupDate;

          for (int i = 0; i < notifications.length; i++) {
            final doc = notifications[i];
            final data = doc.data() as Map<String, dynamic>;
            final Timestamp? timeData = data['timestamp'] ?? data['createdAt'];

            // 1. Check if we need to insert a Date Header
            String dateLabel = _getGroupDateString(timeData);
            if (dateLabel != currentGroupDate) {
              currentGroupDate = dateLabel;
              listItems.add(
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
                  child: Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade500,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              );
            }

            // 2. Build the Notification Tile
            final bool isRead = data['isRead'] ?? false;
            final String type = data['type'] ?? 'system';
            final bool isEmergency = type == 'emergency';
            final String titleText = data['title'] ?? 'Notification';
            final String bodyText = data['body'] ?? data['message'] ?? '';

            Color tileBgColor = isRead ? Colors.white : const Color(0xFFFFF8ED).withOpacity(0.5);
            if (isEmergency && !isRead) tileBgColor = Colors.red.shade50;

            listItems.add(
              Container(
                color: tileBgColor,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isRead ? Colors.grey.shade100 : const Color(0xFFFFF8ED), shape: BoxShape.circle),
                    child: Icon(_getIconForType(type), color: isRead ? Colors.grey.shade500 : const Color(0xFFF39C12), size: 24),
                  ),
                  title: Text(titleText, style: TextStyle(fontWeight: isRead ? FontWeight.w600 : FontWeight.bold, fontSize: 15)),
                  subtitle: Text(bodyText, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () async {
                    if (!isRead) await _markAsRead(doc.id);

                    if (type == 'leave_request') {
                      final String? leaveRequestId = data['leaveRequestId'];
                      if (leaveRequestId != null) {
                        try {
                          final leaveDoc = await FirebaseFirestore.instance.collection('leave_requests').doc(leaveRequestId).get();
                          if (leaveDoc.exists && leaveDoc.data()!['status'] == 'Pending') {
                            if (!context.mounted) return;
                            _showLeaveDetailDialog(context, leaveDoc);
                            return;
                          } else {
                            if (!context.mounted) return;
                            _showPopupMessage("Notice", "This leave request has already been processed or cancelled.");
                            return;
                          }
                        } catch (e) {
                          debugPrint("Error fetching leave request: $e");
                        }
                      }
                      if (!context.mounted) return;
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaveApprovalsScreen()));

                    } else if (type == 'medical_claim') {
                      // --- FETCH AND DISPLAY SPECIFIC MEDICAL CLAIM (FULL PAGE) ---
                      final String? claimId = data['claimId'];
                      if (claimId != null) {
                        try {
                          final claimDoc = await FirebaseFirestore.instance.collection('medical_claims').doc(claimId).get();
                          if (claimDoc.exists && claimDoc.data()!['status'] == 'Pending') {
                            if (!context.mounted) return;

                            // Navigate to the beautiful new details page
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MedicalClaimDetailScreen(claimDoc: claimDoc),
                              ),
                            );

                            return;
                          } else {
                            if (!context.mounted) return;
                            _showPopupMessage("Notice", "This medical claim has already been processed.");
                            return;
                          }
                        } catch (e) {
                          debugPrint("Error fetching medical claim: $e");
                        }
                      }
                    } else {
                      // Standard generic notification
                      _showNotificationDetails(context, titleText, bodyText, timeData, type);
                    }
                  },
                ),
              ),
            );

            // 3. Add a divider between items of the SAME date
            if (i < notifications.length - 1) {
              final nextData = notifications[i + 1].data() as Map<String, dynamic>;
              final nextTime = nextData['timestamp'] ?? nextData['createdAt'];
              if (_getGroupDateString(nextTime) == dateLabel) {
                listItems.add(Divider(color: Colors.grey.shade200, height: 1, indent: 24, endIndent: 24));
              }
            }
          }

          // Render the custom list
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 40),
            children: listItems,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400), const Text("Inbox Zero!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]));
}