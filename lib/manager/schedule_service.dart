import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScheduleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── Get company code ─────────────────────────────────────────────
  Future<String?> getCompanyCode() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['company_code'];
  }

  // ─── Format date key ──────────────────────────────────────────────
  String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day
          .toString().padLeft(2, '0')}';

  // ─── Stream entries for a specific day ───────────────────────────
  // FIXED: Returns Future<Stream> instead of async*
  Future<Stream<List<Map<String, dynamic>>>> getEntriesStreamForDay(
      DateTime date,) async {
    final companyCode = await getCompanyCode();
    if (companyCode == null) {
      return const Stream.empty();
    }

    return _db
        .collection('schedules')
        .doc(companyCode)
        .collection('days')
        .doc(dateKey(date))
        .collection('entries')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) =>
          snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
    );
  }

  // ─── Stream ALL entries for current month (for dot indicators) ───
  // FIXED: Returns Future<Stream> instead of async*
  Future<Stream<List<String>>> getDatesWithEventsStream(DateTime month) async {
    final companyCode = await getCompanyCode();
    if (companyCode == null) {
      return const Stream.empty();
    }

    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';

    return _db
        .collection('schedules')
        .doc(companyCode)
        .collection('days')
        .snapshots()
        .map(
          (snap) =>
          snap.docs
              .where((doc) => doc.id.startsWith(prefix))
              .map((doc) => doc.id)
              .toList(),
    );
  }

  // ─── Add shift ────────────────────────────────────────────────────
  Future<void> addShift({
    required DateTime date,
    required String employeeName,
    required String employeePhone,
    required String shiftDetail,
  }) async {
    final companyCode = await getCompanyCode();
    if (companyCode == null) throw Exception('Company code not found');

    final today = DateTime.now();
    final selectedDate = DateTime(date.year, date.month, date.day);
    final todayDate = DateTime(today.year, today.month, today.day);
    if (selectedDate.isBefore(todayDate)) {
      throw Exception('Cannot add schedule for past dates');
    }

    await _db
        .collection('schedules')
        .doc(companyCode)
        .collection('days')
        .doc(dateKey(date))
        .collection('entries')
        .add({
      'employeeName': employeeName,
      'employeePhone': employeePhone,
      'type': 'shift',
      'detail': shiftDetail,
      'status': 'approved',
      'createdBy': 'manager',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Add leave ────────────────────────────────────────────────────
  Future<void> addLeave({
    required DateTime date,
    required String employeeName,
    required String employeePhone,
    required String reason,
  }) async {
    final companyCode = await getCompanyCode();
    if (companyCode == null) throw Exception('Company code not found');

    final batch = _db.batch();

    final entryRef = _db
        .collection('schedules')
        .doc(companyCode)
        .collection('days')
        .doc(dateKey(date))
        .collection('entries')
        .doc();

    batch.set(entryRef, {
      'employeeName': employeeName,
      'employeePhone': employeePhone,
      'type': 'leave',
      'detail': reason,
      'status': 'approved',
      'createdBy': 'manager',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final userRef = _db.collection('pre_authorized_users').doc(employeePhone);
    batch.update(userRef, {'status': 'On Leave'});

    await batch.commit();
  }

  // ─── Delete entry ─────────────────────────────────────────────────
  Future<void> deleteEntry({
    required DateTime date,
    required String entryId,
  }) async {
    final companyCode = await getCompanyCode();
    if (companyCode == null) return;

    await _db
        .collection('schedules')
        .doc(companyCode)
        .collection('days')
        .doc(dateKey(date))
        .collection('entries')
        .doc(entryId)
        .delete();
  }

  // ─── Stream pending leave requests ───────────────────────────────
  Future<Stream<List<Map<String, dynamic>>>>
  getPendingLeaveRequestsStream() async {
    final companyCode = await getCompanyCode();
    if (companyCode == null) return const Stream.empty();

    return _db
        .collection('leave_requests')
        .where('companyCode', isEqualTo: companyCode)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
          snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
    );
  }

  // ─── Approve leave request ────────────────────────────────────────
  Future<void> approveLeaveRequest(Map<String, dynamic> request) async {
    final companyCode = await getCompanyCode();
    if (companyCode == null) return;

    final batch = _db.batch();

    final requestRef = _db.collection('leave_requests').doc(request['id']);
    batch.update(requestRef, {'status': 'approved'});

    final date = request['date'];
    final entryRef = _db
        .collection('schedules')
        .doc(companyCode)
        .collection('days')
        .doc(date)
        .collection('entries')
        .doc();

    batch.set(entryRef, {
      'employeeName': request['employeeName'],
      'employeePhone': request['employeePhone'],
      'type': 'leave',
      'detail': request['reason'],
      'status': 'approved',
      'createdBy': 'employee',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final userRef = _db
        .collection('pre_authorized_users')
        .doc(request['employeePhone']);
    batch.update(userRef, {'status': 'On Leave'});

    await batch.commit();
  }

  // ─── Reject leave request ─────────────────────────────────────────
  Future<void> rejectLeaveRequest(String requestId) async {
    await _db.collection('leave_requests').doc(requestId).update({
      'status': 'rejected',
    });
  }

  // ─── Today's summary (UPDATED TO USE REAL DATA) ──────────────────
  Future<Map<String, int>> getTodaySummary() async {
    final companyCode = await getCompanyCode();
    if (companyCode == null) {
      return {'Present': 0, 'On Leave': 0, 'Absent': 0};
    }

    int present = 0,
        onLeave = 0,
        absent = 0;
    String todayDate = "${DateTime
        .now()
        .year}-${DateTime
        .now()
        .month
        .toString()
        .padLeft(2, '0')}-${DateTime
        .now()
        .day
        .toString()
        .padLeft(2, '0')}";

    // 1. Get all employees for this company
    final snap = await _db
        .collection('users')
        .where('company_code', isEqualTo: companyCode)
        .where('role', isEqualTo: 'Employee')
        .get();

    for (var doc in snap.docs) {
      String empUid = doc.id;
      bool isPresent = false;
      bool isOnLeave = false;

      // 2. Check if they checked in today
      var attendanceDoc = await _db.collection('users').doc(empUid).collection(
          'attendance').doc(todayDate).get();
      if (attendanceDoc.exists &&
          attendanceDoc.data()?['checkInTime'] != null) {
        isPresent = true;
      }

      // 3. Check if they are on approved leave today
      if (!isPresent) {
        var leaveSnapshot = await _db.collection('leave_requests')
            .where('userId', isEqualTo: empUid)
            .where('status', isEqualTo: 'Approved')
            .get();

        DateTime today = DateTime.now();
        for (var leave in leaveSnapshot.docs) {
          DateTime start = (leave['startDate'] as Timestamp).toDate();
          DateTime end = (leave['endDate'] as Timestamp).toDate();

          DateTime normStart = DateTime(start.year, start.month, start.day);
          DateTime normEnd = DateTime(end.year, end.month, end.day);
          DateTime normToday = DateTime(today.year, today.month, today.day);

          if ((normToday.isAfter(normStart) ||
              normToday.isAtSameMomentAs(normStart)) &&
              (normToday.isBefore(normEnd) ||
                  normToday.isAtSameMomentAs(normEnd))) {
            isOnLeave = true;
            break;
          }
        }
      }

      // 4. Tally the results
      if (isPresent) {
        present++;
      } else if (isOnLeave) {
        onLeave++;
      } else {
        absent++;
      }
    }

    return {'Present': present, 'On Leave': onLeave, 'Absent': absent};
  }
}
