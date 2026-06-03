import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ontime/main.dart';
import 'package:ontime/services/secure_storage_helper.dart';
import 'package:ontime/shared/pin_screen.dart';

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  String userName = "Employee";
  String userEmail = "Loading...";
  String userPhone = "Loading...";
  String userRole = "Employee";
  String? profileImageUrl;

  bool isLoading = true;
  bool isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            userName = doc.data()?['name'] ?? userName;
            userEmail = user.email ?? "No Email";
            userPhone = doc.data()?['phone'] ?? "No Phone Number";
            userRole = doc.data()?['role'] ?? "Employee";
            profileImageUrl = doc.data()?['profileImageUrl'];
            isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error fetching profile: $e");
        if (mounted) setState(() => isLoading = false);
      }
    }
  }

  // --- POP-UP NOTIFICATION HELPER ---
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- PICK AND UPLOAD IMAGE LOGIC ---
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFF39C12)),
                title: const Text('Photo Gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (image != null) _uploadImageToFirebase(File(image.path));
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Color(0xFFF39C12)),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                  if (photo != null) _uploadImageToFirebase(File(photo.path));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadImageToFirebase(File imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isUploadingImage = true);

    try {
      Reference storageRef = FirebaseStorage.instance.ref().child('profile_images/${user.uid}.jpg');
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'profileImageUrl': downloadUrl,
      });

      if (mounted) {
        setState(() {
          profileImageUrl = downloadUrl;
          isUploadingImage = false;
        });
        _showPopupMessage("Success", "Profile picture updated successfully!");
      }
    } catch (e) {
      if (mounted) {
        setState(() => isUploadingImage = false);
        _showPopupMessage("Upload Failed", "Error uploading image: $e", isError: true);
      }
    }
  }

  // --- EDIT EMAIL DIALOG ---
  void _showEditEmailDialog() {
    final TextEditingController emailController = TextEditingController(text: userEmail == "No Email" ? "" : userEmail);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Update Email", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Enter your new email address below.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email Address",
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (emailController.text.isEmpty || !emailController.text.contains('@')) return;
                    setDialogState(() => isSaving = true);

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                          'email': emailController.text.trim(),
                        });

                        try {
                          await user.verifyBeforeUpdateEmail(emailController.text.trim());
                        } catch (e) {
                          debugPrint("Auth update skipped/failed: $e");
                        }

                        if (mounted) {
                          setState(() {
                            userEmail = emailController.text.trim();
                          });
                        }
                      }
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        _showPopupMessage("Success", "Email address updated successfully!");
                      }
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      if (dialogContext.mounted) {
                        _showPopupMessage("Error", "Could not update email: $e", isError: true);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF39C12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Save", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("Are you sure you want to securely log out of your account?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                await SecureStorageHelper().deletePin();
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthGate()),
                      (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showEditPhoneWarning() {
    _showPopupMessage("Manager Approval Required", "To change your official contact phone number, please contact your Manager or HR department.", isError: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        title: const Text("My Profile", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF39C12)))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          children: [
            // --- 1. PROFILE HEADER ---
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: isUploadingImage ? null : _pickAndUploadImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        // CHANGED: Removed NetworkImage fallback and replaced with Icons.person
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.orange.shade50,
                          backgroundImage: profileImageUrl != null
                              ? NetworkImage(profileImageUrl!)
                              : null,
                          child: isUploadingImage
                              ? const CircularProgressIndicator(color: Color(0xFFF39C12))
                              : (profileImageUrl == null
                              ? Icon(Icons.person, size: 50, color: Colors.orange.shade200)
                              : null),
                        ),
                        if (!isUploadingImage)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF39C12),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2)
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20)),
                    child: Text(userRole, style: const TextStyle(color: Color(0xFFF39C12), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // --- 2. PERSONAL INFO ---
            const Align(alignment: Alignment.centerLeft, child: Text("Personal Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  _buildProfileTile(Icons.email_outlined, "Email Address", userEmail, showEdit: true, onTap: _showEditEmailDialog),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _buildProfileTile(Icons.phone_outlined, "Phone Number", userPhone, isLocked: true, onTap: _showEditPhoneWarning),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // --- 3. SECURITY & SETTINGS ---
            const Align(alignment: Alignment.centerLeft, child: Text("Security & Preferences", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  _buildProfileTile(Icons.lock_outline, "Change Security PIN", "Update your 4-digit login PIN", isAction: true, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PinScreen(isCreatingPin: true, userRole: 'Employee')));
                  }),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _buildProfileTile(Icons.help_outline, "Help & Support", "Contact HR or IT", isAction: true, onTap: () {
                    _showPopupMessage("Help & Support", "Routing to IT Support system...");
                  }),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // --- 4. LOGOUT BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: _showLogoutDialog,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text("Log Out", style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("App Version 1.0.0", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String subtitle, {bool isAction = false, bool showEdit = false, bool isLocked = false, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFFF39C12), size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      trailing: isLocked
          ? const Icon(Icons.lock_outline, color: Colors.grey, size: 20)
          : isAction
          ? const Icon(Icons.chevron_right, color: Colors.grey)
          : showEdit ? const Icon(Icons.edit, color: Colors.grey, size: 20) : null,
    );
  }
}