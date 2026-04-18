import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmployeeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── Get current manager's company code ───────────────────────────
  Future<String?> getManagerCompanyCode() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['company_code'];
  }

  // ─── Stream employees from pre_authorized_users ───────────────────
  Stream<List<Map<String, dynamic>>> streamEmployees() async* {
    final companyCode = await getManagerCompanyCode();
    if (companyCode == null) return;

    yield* _db
        .collection('pre_authorized_users')
        .where('company_code', isEqualTo: companyCode)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            return {'phone': doc.id, ...doc.data()};
          }).toList(),
        );
  }

  // ─── Add new employee ─────────────────────────────────────────────
  Future<void> addEmployee({
    required String name,
    required String phone,
    required String role,
  }) async {
    final companyCode = await getManagerCompanyCode();
    if (companyCode == null) throw Exception('Company code not found');

    await _db.collection('pre_authorized_users').doc(phone).set({
      'name': name,
      'role': role,
      'company_code': companyCode,
      'invited': true,
      'status': 'Present',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Update employee details ──────────────────────────────────────
  Future<void> updateEmployee({
    required String phone,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection('pre_authorized_users').doc(phone).update(data);
  }

  // ─── Update status only ───────────────────────────────────────────
  Future<void> updateStatus(String phone, String status) async {
    await _db.collection('pre_authorized_users').doc(phone).update({
      'status': status,
    });
  }

  // ─── Delete employee ──────────────────────────────────────────────
  Future<void> deleteEmployee(String phone) async {
    await _db.collection('pre_authorized_users').doc(phone).delete();
  }
}
