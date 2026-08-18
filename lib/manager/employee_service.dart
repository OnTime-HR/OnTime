import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class EmployeeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── Stream Real Employees & Calculate Status ───────────────────
  Stream<List<Map<String, dynamic>>> streamEmployeesWithStatus() async* {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // 1. Get the manager's profile to find their company code
    final managerDoc = await _db.collection('users').doc(uid).get();
    final companyCode = managerDoc.data()?['company_code'];
    if (companyCode == null) return;

    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 2. Stream all employees in the same company
    yield* _db
        .collection('users')
        .where('company_code', isEqualTo: companyCode)
        .where('role', isEqualTo: 'Employee')
        .snapshots()
        .asyncMap((snapshot) async {

      List<Map<String, dynamic>> employeeList = [];

      for (var doc in snapshot.docs) {
        var empData = doc.data();
        String empUid = doc.id;
        String currentStatus = 'Absent'; // Default to absent

        // 3. Check if they are On Leave today
        var leaveSnapshot = await _db.collection('leave_requests')
            .where('userId', isEqualTo: empUid)
            .where('status', isEqualTo: 'Approved')
            .get();

        bool isOnLeave = false;
        DateTime today = DateTime.now();
        for (var leave in leaveSnapshot.docs) {
          DateTime start = (leave['startDate'] as Timestamp).toDate();
          DateTime end = (leave['endDate'] as Timestamp).toDate();
          // Normalize dates to ignore times
          DateTime normalizedStart = DateTime(start.year, start.month, start.day);
          DateTime normalizedEnd = DateTime(end.year, end.month, end.day);
          DateTime normalizedToday = DateTime(today.year, today.month, today.day);

          if ((normalizedToday.isAfter(normalizedStart) || normalizedToday.isAtSameMomentAs(normalizedStart)) &&
              (normalizedToday.isBefore(normalizedEnd) || normalizedToday.isAtSameMomentAs(normalizedEnd))) {
            isOnLeave = true;
            break;
          }
        }

        if (isOnLeave) {
          currentStatus = 'On Leave';
        } else {
          // 4. If not on leave, check if they Checked In today!
          var attendanceDoc = await _db.collection('users').doc(empUid).collection('attendance').doc(todayDate).get();
          if (attendanceDoc.exists && attendanceDoc.data()?['checkInTime'] != null) {
            currentStatus = 'Present';
          }
        }

        employeeList.add({
          'uid': empUid,
          'name': empData['name'] ?? 'Unknown Employee',
          'role': empData['jobTitle'] ?? 'Employee',
          'phone': empData['phone'] ?? 'No Phone',
          'status': currentStatus,
        });
      }

      return employeeList;
    });
  }
}