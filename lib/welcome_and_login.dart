import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'otp_screen.dart';

class WelcomeLoginScreen extends StatefulWidget {
  const WelcomeLoginScreen({super.key});

  @override
  State<WelcomeLoginScreen> createState() => _WelcomeLoginScreenState();
}

class _WelcomeLoginScreenState extends State<WelcomeLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final String _selectedCountryCode = '+94';
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _validateAndSendOtp() async {
    final phone = '$_selectedCountryCode${_phoneController.text.trim()}';
    final code = _codeController.text.trim();

    print("SEARCHING FOR: Phone: [$phone], Code: [$code]");

    setState(() => _isLoading = true);

    try {
      // FIX: Check the Document ID directly instead of using .where()
      var doc = await FirebaseFirestore.instance
          .collection('pre_authorized_users')
          .doc(phone)
          .get();

      if (doc.exists) {
        var userData = doc.data()!; // Get the data

        // Make sure we ignore spaces and uppercase/lowercase differences
        String dbCode = (userData['company_code'] ?? "")
            .toString()
            .trim()
            .toUpperCase();
        String enteredCode = code.trim().toUpperCase();

        if (dbCode == enteredCode) {
          print("Match found! Triggering OTP...");
          _verifyPhoneNumber(phone);
        } else {
          setState(() => _isLoading = false);
          print("Code mismatch. DB has: $dbCode, User entered: $enteredCode");
          _showSnackBar('Invalid Company Code for this number.');
        }
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Phone number not authorized in system.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Firestore Error: $e");
      _showSnackBar("Error: ${e.toString()}");
    }
  }

  void _verifyPhoneNumber(String phoneNumber) async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      // FIX: Handle the case where Android auto-verifies the test number
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          // If auto-verify works, pop to AuthGate which will open Dashboard
          if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
        } catch (e) {
          debugPrint("Auto-verify failed: $e");
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        _showSnackBar(e.message ?? "Verification failed");
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              phoneNumber: phoneNumber,
              verificationId: verificationId,
            ),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 80),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.business_center_outlined,
                size: 44,
                color: Color(0xFFF5A623),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Log In',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Enter details to access your dashboard',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 36),
            _buildInputField(
              label: 'Company Code',
              controller: _codeController,
              hint: 'e.g. COM100',
              icon: Icons.vpn_key_outlined,
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mobile Number',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    _selectedCountryCode,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '763777417',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _validateAndSendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5A623),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Send Verification Code',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
