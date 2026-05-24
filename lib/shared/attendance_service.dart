import 'dart:async'; // Required for StreamSubscription
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Keep track of the background stream so we can turn it off
  StreamSubscription<Position>? _positionStreamSubscription;

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

    GeoPoint? geoPoint = officeData?['location'] as GeoPoint?;

    return {
      'latitude': geoPoint?.latitude ?? 0.0,
      'longitude': geoPoint?.longitude ?? 0.0,
      'radius': officeData?['radius']?.toDouble() ?? 100.0,
    };
  }

  // --- 4. RECORD ATTENDANCE & CALCULATE WORK TIME ---
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
        'totalWorkingTime': null, // Initialize empty
      }, SetOptions(merge: true));

    } else if (type == 'check_out') {
      // Fetch the check-in time to calculate duration
      DocumentSnapshot docSnapshot = await attendanceDoc.get();
      String? checkInTimeString = docSnapshot.get('checkInTime');
      String durationWorked = "Unknown";

      if (checkInTimeString != null) {
        // Parse the times to calculate the difference
        DateFormat format = DateFormat("hh:mm a");
        DateTime checkIn = format.parse(checkInTimeString);
        DateTime checkOut = format.parse(timeNow);

        // Handle night shifts crossing midnight (if applicable)
        if (checkOut.isBefore(checkIn)) {
          checkOut = checkOut.add(const Duration(days: 1));
        }

        Duration worked = checkOut.difference(checkIn);
        durationWorked = "${worked.inHours}h ${worked.inMinutes.remainder(60)}m";
      }

      await attendanceDoc.update({
        'checkOutTime': timeNow,
        'checkOutLocation': GeoPoint(position.latitude, position.longitude),
        'totalWorkingTime': durationWorked, // Saves the calculated time here!
        'status': 'Checked Out',
      });
    }
  }

  // --- 5. REAL-TIME UI STREAM ---
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

  // --- 6. AUTO-ATTENDANCE BACKGROUND TRACKER ---
  void startAutoAttendance() async {
    // Stop any existing stream before starting a new one
    stopAutoAttendance();

    try {
      // Ensure permissions are granted before starting the stream
      await getCurrentLocation();
      Map<String, dynamic> assigned = await getAssignedLocation();
      final user = _auth.currentUser;
      if (user == null) return;

      LocationSettings locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Only updates if the user moves 10 meters (saves battery)
      );

      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
        String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        DocumentReference attendanceDoc = _db.collection('users').doc(user.uid).collection('attendance').doc(todayDate);

        DocumentSnapshot snapshot = await attendanceDoc.get();
        bool isCheckedIn = snapshot.exists && snapshot.get('checkInTime') != null;
        bool isCheckedOut = snapshot.exists && (snapshot.data() as Map<String, dynamic>).containsKey('checkOutTime') && snapshot.get('checkOutTime') != null;

        // Skip if they already completed their shift for today
        if (isCheckedOut) return;

        bool isInside = isWithinGeofence(position, assigned['latitude'], assigned['longitude'], assigned['radius']);

        // Scenario 1: Inside the geofence but hasn't checked in yet
        if (isInside && !isCheckedIn) {
          debugPrint("Auto-Tracker: User entered geofence. Checking in...");
          await markAttendance('check_in', position);
        }
        // Scenario 2: Outside the geofence, WAS checked in, but hasn't checked out
        else if (!isInside && isCheckedIn) {
          debugPrint("Auto-Tracker: User left geofence. Checking out...");
          await markAttendance('check_out', position);

          // Optionally, auto-turn off the stream once they check out for the day
          stopAutoAttendance();
        }
      });
    } catch (e) {
      debugPrint("Auto-Attendance Error: $e");
    }
  }

  void stopAutoAttendance() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    debugPrint("Auto-Tracker: Service Stopped.");
  }
}