import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EmergencyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> triggerEmergencySOS({
    required String userId,
    required String userName,
    required String userRole,
    required String reason,
  }) async {
    try {
      // 1. Save the official emergency record globally
      final alertRef = await _db.collection('emergency_alerts').add({
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active', // Can be updated later by admins to 'resolved'
      });

      // Use a WriteBatch to send all notifications at the exact same time safely
      WriteBatch batch = _db.batch();

      // --- 2. NOTIFY MANAGERS (Only if the sender is an Employee) ---
      if (userRole == 'Employee') {
        final managerSnapshot = await _db
            .collection('users')
            .where('role', isEqualTo: 'Manager')
            .get();

        for (var doc in managerSnapshot.docs) {
          final notifRef = _db.collection('users').doc(doc.id).collection('notifications').doc();

          batch.set(notifRef, {
            'title': '🚨 EMERGENCY SOS: $userName',
            'body': 'Emergency Checkout Reason: $reason',
            'type': 'emergency',
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
            'alertId': alertRef.id,
            'senderId': userId,
          });
        }
      }

      // --- 3. NOTIFY ADMINS (Always happens, regardless of who sent it) ---
      // We query your dedicated 'admins' collection shown in your Firestore!
      final adminSnapshot = await _db.collection('admins').get();

      for (var doc in adminSnapshot.docs) {
        // Writes to a subcollection: admins / {adminId} / notifications
        final adminNotifRef = _db.collection('admins').doc(doc.id).collection('notifications').doc();

        batch.set(adminNotifRef, {
          'title': '🚨 EMERGENCY SOS: $userName ($userRole)',
          'body': 'Emergency Checkout Reason: $reason',
          'type': 'emergency',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
          'alertId': alertRef.id,
          'senderId': userId,
        });
      }

      // 4. Commit all the writes at once
      await batch.commit();

    } catch (e) {
      debugPrint("Error sending Emergency SOS: $e");
      rethrow;
    }
  }
}