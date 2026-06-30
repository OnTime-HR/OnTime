import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class MedicalClaimDetailScreen extends StatefulWidget {
  final DocumentSnapshot claimDoc;

  const MedicalClaimDetailScreen({super.key, required this.claimDoc});

  @override
  State<MedicalClaimDetailScreen> createState() => _MedicalClaimDetailScreenState();
}

class _MedicalClaimDetailScreenState extends State<MedicalClaimDetailScreen> {
  bool _isProcessing = false;

  Future<void> _downloadReceipt(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        _showPopupMessage("Error", "Could not open the receipt link.", isError: true);
      }
    }
  }

  void _showPopupMessage(String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
              style: ElevatedButton.styleFrom(backgroundColor: isError ? Colors.red : Colors.green),
              onPressed: () {
                Navigator.pop(context); // Close dialog
                if (!isError) {
                  Navigator.pop(context); // Go back to notifications screen on success
                }
              },
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _confirmApproval(String docId, String employeeId, String employeeName, String claimType) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Confirm Approval", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        content: Text("Are you sure you want to approve this $claimType for $employeeName?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(ctx); // Close confirmation dialog
              setState(() => _isProcessing = true);

              try {
                await FirebaseFirestore.instance.collection('medical_claims').doc(docId).update({'status': 'Approved'});
                await FirebaseFirestore.instance.collection('users').doc(employeeId).collection('notifications').add({
                  'title': 'Claim Approved',
                  'body': 'Your $claimType claim has been approved.',
                  'type': 'system',
                  'isRead': false,
                  'timestamp': FieldValue.serverTimestamp(),
                });
                _showPopupMessage("Approved", "Medical claim has been approved.", isError: false);
              } catch (e) {
                _showPopupMessage("Error", "Failed to approve claim.", isError: true);
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
            child: const Text("Yes, Approve", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmRejection(String docId, String employeeId, String employeeName, String claimType) {
    TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Reject Claim", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Please provide a reason for rejecting this claim from $employeeName.", style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(hintText: "Reason for rejection...", filled: true, fillColor: Colors.red.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A reason is required to reject."), backgroundColor: Colors.red));
                return;
              }

              Navigator.pop(ctx); // Close dialog
              setState(() => _isProcessing = true);

              try {
                await FirebaseFirestore.instance.collection('medical_claims').doc(docId).update({
                  'status': 'Rejected',
                  'rejectionReason': reasonController.text.trim(),
                });
                await FirebaseFirestore.instance.collection('users').doc(employeeId).collection('notifications').add({
                  'title': 'Claim Rejected',
                  'body': 'Your $claimType claim was rejected. Reason: ${reasonController.text.trim()}',
                  'type': 'system',
                  'isRead': false,
                  'timestamp': FieldValue.serverTimestamp(),
                });
                _showPopupMessage("Rejected", "Medical claim has been rejected.", isError: false); // Not an error, successful rejection
              } catch (e) {
                _showPopupMessage("Error", "Failed to reject claim.", isError: true);
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
            child: const Text("Confirm Reject", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var data = widget.claimDoc.data() as Map<String, dynamic>;
    String docId = widget.claimDoc.id;
    String employeeId = data['userId'] ?? '';
    String employeeName = data['userName'] ?? 'Employee';
    String claimType = data['claimType'] ?? 'Medical Claim';
    String description = data['description'] ?? 'No description provided.';
    double amount = data['amount'] ?? 0.0;
    String receiptUrl = data['receiptUrl'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text("Claim Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF39C12)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: const Icon(Icons.receipt_long, color: Colors.blue, size: 32)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employeeName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const Text("Pending Medical Claim", style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 32),

            // Details Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200)
              ),
              child: Column(
                children: [
                  _buildDetailRow(Icons.category, "Claim Type", claimType),
                  _buildDetailRow(Icons.payments_outlined, "Amount", "LKR ${amount.toStringAsFixed(2)}"),
                  _buildDetailRow(Icons.notes, "Description", description),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Receipt Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Attached Receipt", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (receiptUrl.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _downloadReceipt(receiptUrl),
                    icon: const Icon(Icons.download, color: Color(0xFFF39C12), size: 20),
                    label: const Text("Download", style: TextStyle(color: Color(0xFFF39C12), fontWeight: FontWeight.bold)),
                  )
              ],
            ),
            const SizedBox(height: 16),

            if (receiptUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  color: Colors.grey.shade100,
                  child: Image.network(
                    receiptUrl,
                    fit: BoxFit.contain, // Allows full view without cropping
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFFF39C12))));
                    },
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                child: const Column(
                  children: [
                    Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text("No receipt attached", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

            const SizedBox(height: 100), // Padding for bottom buttons
          ],
        ),
      ),

      // Bottom Action Bar
      bottomSheet: _isProcessing ? null : Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), foregroundColor: Colors.red, side: const BorderSide(color: Colors.red, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => _confirmRejection(docId, employeeId, employeeName, claimType),
                child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => _confirmApproval(docId, employeeId, employeeName, claimType),
                child: const Text("Approve", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}