import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpScreen({super.key, required this.phoneNumber, required this.verificationId});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isProcessingProfile = false; // FIX: Prevents double-loading
  StreamSubscription<User?>? _authSubscription;

  bool get _isOtpComplete => _controllers.every((c) => c.text.isNotEmpty);

  @override
  void initState() {
    super.initState();
    // BACKGROUND LISTENER: Catches the "Ghost Login" instantly
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null && mounted) {
        _processUserLogin(user);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    for (var c in _controllers) { c.dispose(); }
    for (var f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  // MANUAL VERIFICATION
  Future<void> _verifyOtp() async {
    if (!_isOtpComplete || _isVerifying || _isProcessingProfile) return;

    setState(() => _isVerifying = true);
    final otp = _controllers.map((c) => c.text).join();
    FocusScope.of(context).unfocus(); // Hide keyboard

    try {
      // Try to manually log in
      AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      // If successful, process the profile
      if (FirebaseAuth.instance.currentUser != null) {
        await _processUserLogin(FirebaseAuth.instance.currentUser!);
      }

    } catch (e) {
      // THE MAGIC FIX: If Firebase throws an error, check if the background listener
      // actually succeeded while we were clicking the button!
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        debugPrint("Race condition caught! User is actually logged in.");
        await _processUserLogin(user);
        return;
      }

      // If genuinely failed, show error
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid code. Please check and try again.")),
        );
      }
    }
  }

  // FIRESTORE PROFILE CREATION
  Future<void> _processUserLogin(User user) async {
    // Prevent this function from running twice if both Manual and Background succeed
    if (_isProcessingProfile) return;
    _isProcessingProfile = true;

    if (mounted) setState(() => _isVerifying = true);

    try {
      // FIX: Query the Document ID directly instead of using .where()
      final DocumentSnapshot whitelistDoc = await FirebaseFirestore.instance
          .collection('pre_authorized_users')
          .doc(widget.phoneNumber)
          .get();

      Map<String, dynamic> staffData = {};
      if (whitelistDoc.exists && whitelistDoc.data() != null) {
        staffData = whitelistDoc.data() as Map<String, dynamic>;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'phone': widget.phoneNumber,
        // Now it will successfully find the name from staffData!
        'name': staffData['name'] ?? 'Alex',
        'company_code': staffData['company_code'] ?? 'COM100',
        'role': staffData['role'] ?? 'Employee',
        'isSetupComplete': true,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      // Navigate safely to the Dashboard
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthGate()),
            (route) => false,
      );
    } catch (e) {
      debugPrint("Error creating user profile: $e");
      _isProcessingProfile = false;
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Verification'), centerTitle: true, backgroundColor: Colors.white, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            const Icon(Icons.lock_outline, size: 60, color: Color(0xFFF5A623)),
            const SizedBox(height: 20),
            const Text('Enter the 6-digit code sent to', style: TextStyle(color: Colors.grey)),
            Text(widget.phoneNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) => SizedBox(
                width: 45,
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,

                  // --- THE SECURITY FIX IS RIGHT HERE ---
                  obscureText: true,           // Hides the numbers from shoulder surfers
                  obscuringCharacter: '●',     // Uses a solid dot for a clean look

                  decoration: InputDecoration(
                      counterText: "",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFF5A623), width: 2), borderRadius: BorderRadius.circular(10))
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && index < 5) _focusNodes[index + 1].requestFocus();
                    if (value.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();

                    // AUTO-SUBMIT: When the 6th number is typed, verify immediately
                    if (value.isNotEmpty && index == 5) {
                      _verifyOtp();
                    }
                  },
                ),
              )),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5A623), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                child: _isVerifying
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Verify & Join', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}