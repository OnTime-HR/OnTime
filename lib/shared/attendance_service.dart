import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- 1. GET USER LOCATION ---
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // --- 2. THE GEOFENCING MATH ---
  bool isWithinGeofence(Position currentPosition, double targetLat, double targetLng, double allowedRadiusInMeters) {
    double distanceInMeters = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      targetLat,
      targetLng,
    );
    return distanceInMeters <= allowedRadiusInMeters;
  }

  // --- 3. FETCH THE ASSIGNED LOCATION ---
  Future<Map<String, dynamic>> getAssignedLocation() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    DocumentSnapshot userDoc = await _db.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception("User profile not found.");

    Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
    if (userData == null || !userData.containsKey('assignedOfficeId') || userData['assignedOfficeId'] == null) {
      throw Exception("You have not been assigned to a work location yet.");
    }

    String officeId = userData['assignedOfficeId'];
    DocumentSnapshot officeDoc = await _db.collection('offices').doc(officeId).get();
    if (!officeDoc.exists) throw Exception("Your assigned branch does not exist.");

    Map<String, dynamic>? officeData = officeDoc.data() as Map<String, dynamic>?;

    return {
      'latitude': officeData?['latitude']?.toDouble() ?? 0.0,
      'longitude': officeData?['longitude']?.toDouble() ?? 0.0,
      'radius': officeData?['radius']?.toDouble() ?? 100.0,
    };
  }

  // --- 4. RECORD ATTENDANCE IN FIRESTORE ---
  Future<void> markAttendance(String type, Position position) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String timeNow = DateFormat('hh:mm a').format(DateTime.now());

    DocumentReference attendanceDoc = _db
        .collection('users')
        .doc(user.uid)
        .collection('attendance')
        .doc(todayDate);

    if (type == 'check_in') {
      await attendanceDoc.set({
        'checkInTime': timeNow,
        'checkInLocation': GeoPoint(position.latitude, position.longitude),
        'status': 'Present',
        'date': todayDate,
        'checkOutTime': null,
        'checkOutLocation': null,
      }, SetOptions(merge: true));
    } else if (type == 'check_out') {
      await attendanceDoc.update({
        'checkOutTime': timeNow,
        'checkOutLocation': GeoPoint(position.latitude, position.longitude),
      });
    }
  }

  // --- NEW: STREAM TODAY'S ATTENDANCE STATUS FOR REAL-TIME UI UPDATES ---
  Stream<DocumentSnapshot> streamTodayAttendance() {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('attendance')
        .doc(todayDate)
        .snapshots();
  }
}