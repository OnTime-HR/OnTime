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

  // Icons tailored for Manager tasks
  IconData _getIconForType(String type) {
    switch (type) {
      case 'leave_request':
        return Icons.event_available_rounded; // An employee wants time off
      case 'medical_claim':
        return Icons.receipt_long_rounded; // An employee submitted a receipt
      case 'admin_alert':
        return Icons.campaign_rounded; // Message from upper management/admin
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

  Future<void> _markAsRead(String docId) async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('notifications')
        .doc(docId)
        .update({'isRead': true});
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

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Center(child: Text("Please log in."));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "Manager Inbox",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text("Mark all read", style: TextStyle(color: Color(0xFFF39C12), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFF39C12)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final notifications = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.only(top: 8, bottom: 40),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200, height: 1),
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;

              final bool isRead = data['isRead'] ?? false;
              final String type = data['type'] ?? 'system';

              return Container(
                color: isRead ? Colors.white : const Color(0xFFFFF8ED).withOpacity(0.5),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isRead ? Colors.grey.shade100 : const Color(0xFFFFF8ED),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getIconForType(type), color: isRead ? Colors.grey.shade500 : const Color(0xFFF39C12), size: 24),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          data['title'] ?? '',
                          style: TextStyle(fontWeight: isRead ? FontWeight.w600 : FontWeight.bold, color: isRead ? Colors.black87 : Colors.black, fontSize: 15),
                        ),
                      ),
                      Text(
                        _getTimeAgo(data['createdAt'] as Timestamp?),
                        style: TextStyle(color: isRead ? Colors.grey.shade500 : const Color(0xFFF39C12), fontSize: 12, fontWeight: isRead ? FontWeight.normal : FontWeight.w600),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(data['message'] ?? '', style: TextStyle(color: isRead ? Colors.grey.shade600 : Colors.black87, fontSize: 13, height: 1.4)),
                  ),
                  onTap: () {
                    if (!isRead) _markAsRead(doc.id);

                    // FIXED: Now it actually navigates!
                    if (type == 'leave_request') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaveApprovalsScreen()));
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFFF8F9FB), shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
            child: Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          const Text("Inbox Zero!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text("No pending requests to review.", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ),
    );
  }
}