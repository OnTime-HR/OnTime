import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; // <-- NEW: For Cloudinary
import 'dart:convert'; // <-- NEW: For parsing Cloudinary response
import 'package:ontime/main.dart';

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
    // 1. Drop the keyboard instantly
    FocusScope.of(context).unfocus();

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

                  // --- THE MISSING HALL PASS ---
                  isPickingMedia = true;

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

                  // --- THE MISSING HALL PASS ---
                  isPickingMedia = true;

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

  // --- BACKEND SUBMISSION FUNCTION (CLOUDINARY + FIRESTORE) ---
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

      // --- NEW: CLOUDINARY UPLOAD LOGIC ---
      // 3. Setup Cloudinary Variables (REPLACE THESE WITH YOUR ACTUAL DETAILS!)
      const String cloudName = "dfqeymqdx";
      const String uploadPreset = "ontimeweb";

      // 4. Prepare the HTTP POST request
      var uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      var request = http.MultipartRequest('POST', uri);

      // Attach the upload preset and the actual image file
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', attachedDocument!.path));

      // 5. Send the file to Cloudinary
      var response = await request.send();
      if (response.statusCode != 200) {
        throw Exception("Failed to upload image to Cloudinary. Status: ${response.statusCode}");
      }

      // 6. Decode the response to get the secure image URL
      var responseData = await response.stream.toBytes();
      var responseString = String.fromCharCodes(responseData);
      var jsonMap = jsonDecode(responseString);
      String downloadUrl = jsonMap['secure_url'];
      // ------------------------------------

      // 7. Save Claim Data to Firestore (Using the Cloudinary URL!)
      final double claimAmount = double.parse(_amountController.text);

      final claimDoc = await FirebaseFirestore.instance.collection('medical_claims').add({
        'userId': user.uid,
        'userName': userName,
        'userRole': role,
        'approverId': approverId, // Keeps your existing dashboard queries working perfectly!
        'claimType': selectedClaimType,
        'amount': claimAmount,
        'description': _descriptionController.text,
        'receiptUrl': downloadUrl,
        'status': 'Pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // 8. Prepare the Notification Data
      final notificationData = {
        'title': 'New Medical Claim',
        'body': '$userName submitted a claim for LKR $claimAmount.',
        'type': 'medical_claim',
        'claimId': claimDoc.id,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // --- NEW: THE HIERARCHY NOTIFICATION LOGIC ---

      // A. ALWAYS notify the Admin (so they have oversight on everyone)
      await FirebaseFirestore.instance
          .collection('users')
          .doc('admin') // Make sure 'admin' is the exact document ID of your admin user!
          .collection('notifications')
          .add(notificationData);

      // B. ALSO notify the Manager (ONLY if the user is an Employee with an assigned manager)
      if (role != 'Manager' && assignedManagerId != 'unassigned') {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(assignedManagerId)
            .collection('notifications')
            .add(notificationData);
      }

      // 9. Success Block
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        _showPopupMessage(
            "Success!",
            "Your medical claim has been successfully submitted."
        );
      }
    } catch (e) {

      // 10. Error Block
      if (mounted) {
        _showPopupMessage(
            "Error",
            "Error submitting claim: $e",
            isError: true
        );
      }
    } finally {
      // 11. Cleanup Block
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
                          Text("LKR 150,000", style: TextStyle(color: Color(0xFFF39C12), fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("Total Limit", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text("LKR 200,000", style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
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