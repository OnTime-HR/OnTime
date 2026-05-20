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

    // Test if location services are enabled.
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
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // --- 2. THE GEOFENCING MATH ---
  // This calculates if the user is within the required radius of the target location
  bool isWithinGeofence(Position currentPosition, double targetLat, double targetLng, double allowedRadiusInMeters) {
    double distanceInMeters = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      targetLat,
      targetLng,
    );

    // If the distance between them and the office is less than the allowed radius, they are inside the fence!
    return distanceInMeters <= allowedRadiusInMeters;
  }

  // --- 3. FETCH THE ASSIGNED LOCATION (DYNAMIC FIRESTORE REAL-TIME FETCH) ---
  Future<Map<String, dynamic>> getAssignedLocation() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    // 1. Get the user's document to find their assigned office
    DocumentSnapshot userDoc = await _db.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      throw Exception("User profile not found.");
    }

    Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;

    // Check if the manager has assigned them a location yet
    if (userData == null || !userData.containsKey('assignedOfficeId') || userData['assignedOfficeId'] == null) {
      throw Exception("You have not been assigned to a work location yet. Please contact your manager.");
    }

    String officeId = userData['assignedOfficeId'];

    // 2. Look up the coordinates for that specific office
    DocumentSnapshot officeDoc = await _db.collection('offices').doc(officeId).get();

    if (!officeDoc.exists) {
      throw Exception("Your assigned branch ($officeId) does not exist in the database.");
    }

    Map<String, dynamic>? officeData = officeDoc.data() as Map<String, dynamic>?;

    // Return the actual coordinates and radius from the database
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

    // Format today's date to use as the document ID (e.g., "2026-05-18")
    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String timeNow = DateFormat('hh:mm a').format(DateTime.now());

    // We save attendance in a subcollection under the user's profile
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
        // We initialize checkOut fields as null so they can be updated later
        'checkOutTime': null,
        'checkOutLocation': null,
      }, SetOptions(merge: true)); // merge: true ensures we don't overwrite if it already exists
    } else if (type == 'check_out') {
      await attendanceDoc.update({
        'checkOutTime': timeNow,
        'checkOutLocation': GeoPoint(position.latitude, position.longitude),
      });
    }
  }
}