import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:local_auth/local_auth.dart'; // NEW: Biometric Package
import 'package:ontime/services/secure_storage_helper.dart';
import 'package:ontime/manager/manager_main_screen.dart';
import 'package:ontime/employee/employee_main.dart';

bool isBiometricAuthenticating = false;

// Defines the exact step the user is currently on
enum PinFlowStep {
  unlock,          // 1. Standard login unlock
  setupCreate,     // 2. First-time setup: Enter PIN
  setupConfirm,    // 3. First-time setup: Confirm PIN
  changeVerifyOld, // 4. Profile settings: Enter current PIN to verify
  changeEnterNew,  // 5. Profile settings: Enter new PIN
  changeConfirmNew // 6. Profile settings: Confirm new PIN
}

class PinScreen extends StatefulWidget {
  final bool isCreatingPin;
  final bool isChangingPin;
  final String userRole;

  const PinScreen({
    Key? key,
    this.isCreatingPin = false,
    this.isChangingPin = false,
    required this.userRole
  }) : super(key: key);

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final SecureStorageHelper _storageHelper = SecureStorageHelper();
  final TextEditingController _pinController = TextEditingController();

  // NEW: Initialize the Local Authentication object
  final LocalAuthentication _auth = LocalAuthentication();

  late PinFlowStep _currentStep;
  String? _firstPinEntry;
  bool _hasError = false;
  String _errorMessage = '';

  // NEW: State variables to track biometric availability
  bool _isBiometricSupported = false;

  @override
  void initState() {
    super.initState();
    if (widget.isChangingPin) {
      _currentStep = PinFlowStep.changeVerifyOld;
    } else if (widget.isCreatingPin) {
      _currentStep = PinFlowStep.setupCreate;
    } else {
      _currentStep = PinFlowStep.unlock;
    }

    // NEW: Check if the device has biometrics and trigger it if unlocking
    _checkBiometricsAndAuthenticate();
  }

  // --- NEW: BIOMETRIC LOGIC ---
  Future<void> _checkBiometricsAndAuthenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (mounted) {
        setState(() {
          _isBiometricSupported = canAuthenticate;
        });
      }


    } catch (e) {
      debugPrint("Error checking biometrics: $e");
    }
  }

  bool _isAuthenticating = false;

  Future<void> _triggerBiometricScan() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Scan to unlock OnTime securely',
        biometricOnly: true,
        persistAcrossBackgrounding: false,
      );

      if (didAuthenticate && mounted) {
        _navigateToDashboard();
      }
    } catch (e) {
      debugPrint("Biometric scan failed or canceled: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }
  // ----------------------------

  void _onSubmit(String pin) async {
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });

    switch (_currentStep) {
    // --- UNLOCK FLOW ---
      case PinFlowStep.unlock:
        String? savedPin = await _storageHelper.getPin();
        if (pin == savedPin) {
          _navigateToDashboard();
        } else {
          _showError('Incorrect code, try again');
        }
        break;

    // --- VERIFY OLD PIN FLOW ---
      case PinFlowStep.changeVerifyOld:
        String? savedPin = await _storageHelper.getPin();
        if (pin == savedPin) {
          setState(() => _currentStep = PinFlowStep.changeEnterNew);
          _pinController.clear();
        } else {
          _showError('Incorrect current PIN. Try again.');
        }
        break;

    // --- STEP 1 OF CREATING/CHANGING ---
      case PinFlowStep.setupCreate:
      case PinFlowStep.changeEnterNew:
        _firstPinEntry = pin;
        setState(() {
          _currentStep = _currentStep == PinFlowStep.setupCreate
              ? PinFlowStep.setupConfirm
              : PinFlowStep.changeConfirmNew;
        });
        _pinController.clear();
        break;

    // --- STEP 2 OF CREATING/CHANGING ---
      case PinFlowStep.setupConfirm:
      case PinFlowStep.changeConfirmNew:
        if (pin == _firstPinEntry) {
          await _storageHelper.savePin(pin);

          if (widget.isChangingPin) {
            if (!mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Security PIN successfully updated!'),
                    backgroundColor: Colors.green
                )
            );
          } else {
            _navigateToDashboard();
          }
        } else {
          _showError('PINs do not match. Please try again.');
          _firstPinEntry = null;
          setState(() {
            _currentStep = _currentStep == PinFlowStep.setupConfirm
                ? PinFlowStep.setupCreate
                : PinFlowStep.changeEnterNew;
          });
        }
        break;
    }
  }

  void _showError(String message) {
    setState(() {
      _hasError = true;
      _errorMessage = message;
      _pinController.clear();
    });
  }

  void _navigateToDashboard() {
    if (widget.userRole == 'Manager') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ManagerMainScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const EmployeeMainScreen()));
    }
  }

  String get _screenTitle {
    switch (_currentStep) {
      case PinFlowStep.unlock:
        return 'Enter Your\nSecurity Code';
      case PinFlowStep.setupCreate:
        return 'Create Your\nSecurity Code';
      case PinFlowStep.setupConfirm:
        return 'Confirm Your\nSecurity Code';
      case PinFlowStep.changeVerifyOld:
        return 'Enter Current\nSecurity Code';
      case PinFlowStep.changeEnterNew:
        return 'Enter New\nSecurity Code';
      case PinFlowStep.changeConfirmNew:
        return 'Confirm New\nSecurity Code';
    }
  }

  String get _buttonText {
    if (_currentStep == PinFlowStep.setupConfirm || _currentStep == PinFlowStep.changeConfirmNew) {
      return 'Confirm';
    }
    return 'Next';
  }

  bool get _requiresManualSubmit {
    return _currentStep != PinFlowStep.unlock && _currentStep != PinFlowStep.changeVerifyOld;
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 55,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 24,
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: const Color(0xFFF5A623), width: 2),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      textStyle: const TextStyle(
        fontSize: 24,
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      decoration: defaultPinTheme.decoration?.copyWith(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.isChangingPin
          ? AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black))
          : null,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: widget.isChangingPin ? 20 : 60),

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

                Text(
                  _screenTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 80),

                Text(
                  'Enter a 4-digit code',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                Pinput(
                  controller: _pinController,
                  length: 4,
                  obscureText: true,
                  obscuringCharacter: '●',
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: submittedPinTheme,
                  onCompleted: _requiresManualSubmit ? null : _onSubmit,
                  showCursor: true,
                  cursor: Container(
                    width: 2,
                    height: 24,
                    color: const Color(0xFFF5A623),
                  ),
                ),

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
                          _errorMessage,
                          style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                if (_requiresManualSubmit)
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
                      child: Text(
                        _buttonText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                // --- NEW: BIOMETRIC FALLBACK BUTTON ---
                // Only show this button if the device supports it AND the user is just trying to unlock
                if (_isBiometricSupported && _currentStep == PinFlowStep.unlock) ...[
                  const SizedBox(height: 30),
                  Text(
                    "OR",
                    style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _triggerBiometricScan,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300)
                      ),
                      child: const Icon(
                          Icons.fingerprint_rounded,
                          size: 40,
                          color: Color(0xFFF5A623)
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text("Use Biometrics", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}