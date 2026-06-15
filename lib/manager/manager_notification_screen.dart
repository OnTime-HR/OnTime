import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ontime/manager/leave_approvals_screen.dart';

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
              decoration: BoxDecoration(
                color: isEmergency ? Colors.red.shade50 : Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
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

          return ListView.separated(
            padding: const EdgeInsets.only(top: 8, bottom: 40),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200, height: 1),
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final bool isRead = data['isRead'] ?? false;
              final String type = data['type'] ?? 'system';
              final bool isEmergency = type == 'emergency';
              final String titleText = data['title'] ?? 'Notification';
              final String bodyText = data['body'] ?? data['message'] ?? '';
              final Timestamp? timeData = data['timestamp'] ?? data['createdAt'];

              Color tileBgColor = isRead ? Colors.white : const Color(0xFFFFF8ED).withOpacity(0.5);
              if (isEmergency && !isRead) tileBgColor = Colors.red.shade50;

              return Container(
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
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaveApprovalsScreen()));
                    } else {
                      _showNotificationDetails(context, titleText, bodyText, timeData, type);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400), const Text("Inbox Zero!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]));
}