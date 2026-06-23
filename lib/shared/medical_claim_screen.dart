import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MedicalClaimScreen extends StatefulWidget {
  const MedicalClaimScreen({super.key});

  @override
  State<MedicalClaimScreen> createState() => _MedicalClaimScreenState();
}

class _MedicalClaimScreenState extends State<MedicalClaimScreen> {
  String? selectedClaimType;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // State variables for image and loading status
  XFile? attachedDocument;
  bool _isSubmitting = false;

  final List<String> claimTypes = [
    'General Consultation',
    'Dental Care',
    'Vision Care',
    'Prescription Medication',
    'Hospitalization',
    'Other'
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Function to pick an image using Camera or Gallery
  Future<void> _pickDocument() async {
    final ImagePicker picker = ImagePicker();

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFF39C12)),
                title: const Text('Photo Gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    setState(() {
                      attachedDocument = image;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Color(0xFFF39C12)),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? photo = await picker.pickImage(source: ImageSource.camera);
                  if (photo != null) {
                    setState(() {
                      attachedDocument = photo;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
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

  // --- BACKEND SUBMISSION FUNCTION ---
  Future<void> _submitClaimToFirebase() async {
    if (selectedClaimType == null || _amountController.text.isEmpty || attachedDocument == null) {
      _showPopupMessage("Missing Fields", "Please fill all fields and attach a receipt.", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated.");

      // 1. Fetch user data to determine routing
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final String role = userData['role'] ?? 'Employee';
      final String userName = userData['name'] ?? 'Unknown User';
      final String assignedManagerId = userData['managerId'] ?? 'unassigned';

      // 2. The Smart Routing Logic
      final String approverId = (role == 'Manager') ? 'admin' : assignedManagerId;

      // 3. Upload Image to Storage
      File file = File(attachedDocument!.path);
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${attachedDocument!.name}';
      Reference storageRef = FirebaseStorage.instance.ref().child('medical_receipts/${user.uid}/$fileName');
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // 4. Save Claim Data with Routing Info
      final double claimAmount = double.parse(_amountController.text);
      await FirebaseFirestore.instance.collection('medical_claims').add({
        'userId': user.uid,
        'userName': userName,
        'userRole': role,
        'approverId': approverId,
        'claimType': selectedClaimType,
        'amount': claimAmount,
        'description': _descriptionController.text,
        'receiptUrl': downloadUrl,
        'status': 'Pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // 5. Send Notification to Approver
      if (approverId != 'unassigned') {
        await FirebaseFirestore.instance.collection('users').doc(approverId).collection('notifications').add({
          'title': 'New Medical Claim',
          'body': '$userName submitted a claim for \$$claimAmount.',
          'type': 'medical_claim',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // 6. Success Block
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        _showPopupMessage(
            "Success!",
            "Your medical claim has been successfully submitted for review."
        );
      }
    } catch (e) {
      // 7. Error Block
      if (mounted) {
        _showPopupMessage(
            "Error",
            "Error submitting claim: $e",
            isError: true
        );
      }
    } finally {
      // 8. Cleanup Block
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
          "Medical Claim",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 1. BALANCE/LIMIT CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8ED),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.health_and_safety_outlined, color: Color(0xFFF39C12)),
                      SizedBox(width: 8),
                      Text("Annual Medical Allowance", style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Remaining", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text("\$1,250.00", style: TextStyle(color: Color(0xFFF39C12), fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("Total Limit", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text("\$2,000.00", style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 2. CLAIM TYPE DROPDOWN
            const Text("Claim Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: selectedClaimType,
              decoration: _buildInputDecoration("Select claim type"),
              icon: const Icon(Icons.keyboard_arrow_down),
              items: claimTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) => setState(() => selectedClaimType = value),
            ),
            const SizedBox(height: 24),

            // 3. AMOUNT FIELD
            const Text("Claim Amount", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _buildInputDecoration("Enter amount").copyWith(
                prefixIcon: const Icon(Icons.attach_money, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),

            // 4. ATTACH DOCUMENT SECTION
            const Text("Receipt / Invoice", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDocument,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
                decoration: BoxDecoration(
                  color: attachedDocument != null ? const Color(0xFFFFF8ED) : const Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: attachedDocument != null ? const Color(0xFFF39C12) : Colors.grey.shade300,
                    style: BorderStyle.solid,
                    width: attachedDocument != null ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      attachedDocument != null ? Icons.check_circle : Icons.cloud_upload_outlined,
                      size: 40,
                      color: attachedDocument != null ? const Color(0xFFF39C12) : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      attachedDocument != null ? "Document Ready" : "Tap to upload receipt or doctor's note",
                      style: TextStyle(
                        color: attachedDocument != null ? const Color(0xFFB45309) : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (attachedDocument == null) ...[
                      const SizedBox(height: 4),
                      Text("JPG or PNG (Max 5MB)", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        attachedDocument!.name,
                        style: const TextStyle(color: Color(0xFFD97706), fontSize: 12, fontStyle: FontStyle.italic),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 5. DESCRIPTION TEXT AREA
            const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: _buildInputDecoration("Briefly describe your medical visit..."),
            ),
            const SizedBox(height: 40),

            // 6. SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitClaimToFirebase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF39C12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 5,
                  shadowColor: const Color(0xFFF39C12).withOpacity(0.4),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                )
                    : const Text(
                  "Submit Claim",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Reusable input decoration
  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
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
        borderSide: const BorderSide(color: Color(0xFFF39C12), width: 2),
      ),
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
    );
  }
}