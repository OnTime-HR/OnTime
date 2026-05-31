import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:ontime/services/secure_storage_helper.dart';
import 'package:ontime/manager/manager_dashboard.dart';
import 'package:ontime/employee/employee_dashboard.dart';

import '../employee/employee_main.dart';
import '../manager/manager_main_screen.dart';
// Import your manager and employee dashboards here

class PinScreen extends StatefulWidget {
  final bool isCreatingPin; // True if first time, False if returning user
  final String userRole; // Pass the RBAC role here ('manager' or 'employee')

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
      // 1. Save the new PIN
      await _storageHelper.savePin(pin);
      _navigateToDashboard();
    } else {
      // 2. Verify the existing PIN
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
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.isCreatingPin ? 'Create your 4-digit PIN' : 'Enter your PIN',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Pinput(
              controller: _pinController,
              length: 4,
              obscureText: true, // Hides the numbers for security
              onCompleted: _onSubmit,
            ),
            if (_hasError) ...[
              const SizedBox(height: 20),
              const Text('Incorrect PIN, try again.', style: TextStyle(color: Colors.red)),
            ]
          ],
        ),
      ),
    );
  }
}