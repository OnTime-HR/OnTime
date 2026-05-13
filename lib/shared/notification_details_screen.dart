import 'package:flutter/material.dart';

class NotificationDetailsScreen extends StatelessWidget {
  final String title;
  final String message;
  final String timeAgo;
  final IconData icon;

  const NotificationDetailsScreen({
    super.key,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.icon,
  });

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
          "Notification Details",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Big Icon Circle
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8ED), // Light Orange
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFDE68A), width: 2),
              ),
              child: Icon(icon, size: 64, color: const Color(0xFFF39C12)),
            ),
            const SizedBox(height: 24),

            // Timestamp
            Text(
              timeAgo,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 30),

            // Message Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                message,
                style: TextStyle(fontSize: 16, height: 1.6, color: Colors.grey.shade800),
              ),
            ),
            const SizedBox(height: 40),

            // Optional "Got it" Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF39C12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 2,
                ),
                child: const Text("Got It", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}