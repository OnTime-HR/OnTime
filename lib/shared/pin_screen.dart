import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:ontime/services/secure_storage_helper.dart';
import 'package:ontime/manager/manager_main_screen.dart';
import 'package:ontime/employee/employee_main.dart';

class PinScreen extends StatefulWidget {
  final bool isCreatingPin;
  final String userRole;

  const PinScreen({Key? key, required this.isCreatingPin, required this.userRole}) : super(key: key);

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final SecureStorageHelper _storageHelper = SecureStorageHelper();
  final TextEditingController _pinController = TextEditingController();
  bool _hasError = false;

  void _onSubmit(String pin) async {
    if (widget.isCreatingPin) {
      await _storageHelper.savePin(pin);
      _navigateToDashboard();
    } else {
      String? savedPin = await _storageHelper.getPin();
      if (pin == savedPin) {
        _navigateToDashboard();
      } else {
        setState(() {
          _hasError = true;
          _pinController.clear();
        });
      }
    }
  }

  void _navigateToDashboard() {
    if (widget.userRole == 'Manager') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ManagerMainScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const EmployeeMainScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- 1. DEFINING THE CUSTOM PIN THEMES ---

    final defaultPinTheme = PinTheme(
      width: 60,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 24,
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.transparent),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: const Color(0xFFF5A623), width: 2),
      color: Colors.white,
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      textStyle: const TextStyle(
        fontSize: 24,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      decoration: defaultPinTheme.decoration?.copyWith(
        color: const Color(0xFFF5A623),
      ),
    );

    // --- 2. THE UI BUILD ---

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // Shield Icon Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8ED),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    size: 32,
                    color: Color(0xFFF5A623),
                  ),
                ),
                const SizedBox(height: 32),

                // Main Title
                Text(
                  widget.isCreatingPin ? 'Create Your\nSecurity Code' : 'Enter Your\nSecurity Code',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 80),

                // Subtitle
                Text(
                  'Enter a 4-digit code',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                // The Custom Pinput Widget
                Pinput(
                  controller: _pinController,
                  length: 4,
                  obscureText: true,
                  obscuringCharacter: '●',
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: submittedPinTheme,

                  // --- THE FIX IS RIGHT HERE ---
                  // If creating PIN, do nothing (null). If verifying, auto-submit!
                  onCompleted: widget.isCreatingPin ? null : _onSubmit,

                  showCursor: true,
                  cursor: Container(
                    width: 2,
                    height: 24,
                    color: const Color(0xFFF5A623),
                  ),
                ),

                // Error Message
                if (_hasError) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade400, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Incorrect code, try again',
                          style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // The Create Button (Only visible when creating a PIN)
                if (widget.isCreatingPin)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_pinController.text.length == 4) {
                          _onSubmit(_pinController.text);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5A623),
                        elevation: 4,
                        shadowColor: const Color(0xFFF5A623).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Create',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}