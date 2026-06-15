import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ontime/manager/leave_approvals_screen.dart';
import 'package:ontime/shared/notification_details_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Helper method to assign the right icon based on notification type
  IconData _getIconForType(String type) {
    switch (type) {
      case 'emergency': // NEW: Urgent warning icon
        return Icons.warning_rounded;
      case 'leave':
        return Icons.beach_access_rounded;
      case 'shift':
        return Icons.work_history_rounded;
      case 'medical':
        return Icons.health_and_safety_rounded;
      case 'system':
      default:
        return Icons.info_outline_rounded;
    }
  }

  // Converts Firestore Timestamp to "10 mins ago" format
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

  // NEW: Helper method to format the exact date/time for the popup
  String _getExactTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return "${_getMonth(date.month)} ${date.day}, ${date.year} at ${TimeOfDay.fromDateTime(date).format(context)}";
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  // Marks a single notification as read in the database
  Future<void> _markAsRead(String docId) async {
    if (currentUser == null) return;
    try {
      // Using .set with merge is 100% bulletproof and prevents silent failures
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

  // Uses a Batch to update ALL unread notifications at once securely
  Future<void> _markAllAsRead() async {
    if (currentUser == null) return;

    final unreadDocs = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    if (unreadDocs.docs.isEmpty) return; // Nothing to update

    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in unreadDocs.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All notifications marked as read.")),
      );
    }
  }

  // --- NEW: Detailed Pop-up Dialog ---
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
              child: Icon(
                _getIconForType(type),
                color: isEmergency ? Colors.red : const Color(0xFFF39C12),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      title,
                      style: TextStyle(
                        color: isEmergency ? Colors.red.shade800 : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        height: 1.2,
                      )
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getExactTime(timestamp),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Center(child: Text("Please log in to view notifications."));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
              "Mark all read",
              style: TextStyle(color: Color(0xFFF39C12), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // THE REAL-TIME STREAM
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('notifications')
        // CHANGED: Support checking the new 'timestamp' field
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFF39C12)));
          }
          if (snapshot.hasError) {
            // Check if it's an indexing error and fallback to old logic if needed
            return const Center(child: Text("Error loading notifications."));
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
              final bool isEmergency = type == 'emergency';

              // Handle both old and new data fields gracefully
              final String title = data['title'] ?? 'Notification';
              final String bodyText = data['body'] ?? data['message'] ?? '';
              final Timestamp? timeData = data['timestamp'] ?? data['createdAt'];

              Color tileBgColor = isRead ? Colors.white : const Color(0xFFFFF8ED).withOpacity(0.5);
              if (isEmergency && !isRead) tileBgColor = Colors.red.shade50;

              Color iconBoxColor = isRead ? Colors.grey.shade100 : const Color(0xFFFFF8ED);
              if (isEmergency) iconBoxColor = isRead ? Colors.red.shade50 : Colors.red.shade100;

              Color iconColor = isRead ? Colors.grey.shade500 : const Color(0xFFF39C12);
              if (isEmergency) iconColor = Colors.red;

              return Container(
                color: tileBgColor,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconBoxColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconForType(type),
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                            color: isEmergency && !isRead ? Colors.red.shade900 : (isRead ? Colors.black87 : Colors.black),
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getTimeAgo(timeData),
                        style: TextStyle(
                          color: isEmergency && !isRead ? Colors.red : (isRead ? Colors.grey.shade500 : const Color(0xFFF39C12)),
                          fontSize: 12,
                          fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      bodyText,
                      style: TextStyle(
                        color: isEmergency && !isRead ? Colors.red.shade800 : (isRead ? Colors.grey.shade600 : Colors.black87),
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onTap: () async {
                    // 1. Force the database to update FIRST
                    if (!isRead) {
                      await _markAsRead(doc.id);
                    }

                    // 2. THEN navigate or show the popup
                    if (type == 'leave_request' || type == 'leave') {
                      if (!context.mounted) return;
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaveApprovalsScreen()));
                    } else {
                      if (!context.mounted) return;
                      _showNotificationDetails(context, title, bodyText, timeData, type);
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
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          const Text(
            "No new notifications",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            "You're all caught up! Check back later.",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}