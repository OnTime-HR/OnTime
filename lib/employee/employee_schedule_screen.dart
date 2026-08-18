import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class EmployeeScheduleScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const EmployeeScheduleScreen({super.key, this.onBack});

  @override
  State<EmployeeScheduleScreen> createState() => _EmployeeScheduleScreenState();
}

class _EmployeeScheduleScreenState extends State<EmployeeScheduleScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  bool _isLoadingUserData = true;

  // Real-time stream subscription for the user's assigned shift
  StreamSubscription? _userSub;
  Map<String, dynamic>? _activeShift; // Will hold the combined user + shift data

  @override
  void initState() {
    super.initState();
    _listenToMySchedule();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  // --- 1. FETCH ASSIGNED SHIFT FROM USER PROFILE ---
  void _listenToMySchedule() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen to the employee's own profile for real-time shift updates
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((userDoc) async {

      if (!userDoc.exists) return;
      var userData = userDoc.data()!;

      String? shiftId = userData['assignedShiftId'];
      String? startStr = userData['shiftStartDate'];
      String? endStr = userData['shiftEndDate'];

      if (shiftId != null && startStr != null && endStr != null) {
        // We have a shift assignment! Let's fetch the actual shift times from the DB
        var shiftDoc = await FirebaseFirestore.instance.collection('shifts').doc(shiftId).get();

        if (shiftDoc.exists) {
          var shiftData = shiftDoc.data()!;
          if (mounted) {
            setState(() {
              _activeShift = {
                'name': shiftData['name'] ?? 'Assigned Shift',
                'startTime': shiftData['start_time'] ?? '--:--',
                'endTime': shiftData['end_time'] ?? '--:--',
                'startDate': DateTime.tryParse(startStr),
                'endDate': DateTime.tryParse(endStr),
              };
              _isLoadingUserData = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoadingUserData = false);
        }
      } else {
        // User has no shift assigned
        if (mounted) {
          setState(() {
            _activeShift = null;
            _isLoadingUserData = false;
          });
        }
      }
    });
  }

  // --- DATE HELPERS ---
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isDateInRange(DateTime target, DateTime? start, DateTime? end) {
    if (start == null || end == null) return false;
    final t = DateTime(target.year, target.month, target.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return (t.isAfter(s) || _isSameDay(t, s)) && (t.isBefore(e) || _isSameDay(t, e));
  }

  void _previousMonth() {
    setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1));
  }

  void _nextMonth() {
    setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1));
  }

  List<DateTime?> _buildCalendarDays() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7;

    final days = <DateTime?>[];
    for (int i = 0; i < startWeekday; i++) { days.add(null); }
    for (int i = 1; i <= lastDay.day; i++) { days.add(DateTime(_focusedMonth.year, _focusedMonth.month, i)); }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUserData) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FB),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFF5A623))),
      );
    }

    final calendarDays = _buildCalendarDays();
    final monthName = DateFormat('MMMM').format(_focusedMonth);

    // Check if the currently selected day has a shift
    bool hasShiftToday = _selectedDay != null && _activeShift != null &&
        _isDateInRange(_selectedDay!, _activeShift!['startDate'], _activeShift!['endDate']);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: widget.onBack, // Routes back to the Home tab
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calendar', style: TextStyle(color: Colors.grey, fontSize: 14)),
            Text(
              'My Schedule',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Monthly Calendar ────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$monthName ${_focusedMonth.year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Row(
                          children: [
                            IconButton(onPressed: _previousMonth, icon: const Icon(Icons.chevron_left), color: Colors.grey),
                            IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right), color: Colors.grey),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(
                            (d) => SizedBox(width: 36, child: Text(d, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade400))),
                      ).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 0, childAspectRatio: 1),
                      itemCount: calendarDays.length,
                      itemBuilder: (_, index) {
                        final day = calendarDays[index];
                        if (day == null) return const SizedBox();

                        final isToday = _isSameDay(day, DateTime.now());
                        final isSelected = _selectedDay != null && _isSameDay(day, _selectedDay!);

                        // Check if this calendar day falls within the user's assigned shift dates
                        final hasEvents = _activeShift != null && _isDateInRange(day, _activeShift!['startDate'], _activeShift!['endDate']);

                        return GestureDetector(
                          onTap: () => setState(() => _selectedDay = day),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFF5A623) : isToday ? const Color(0xFFFFF3E0) : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${day.day}', style: TextStyle(fontSize: 13, fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : isToday ? const Color(0xFFF5A623) : Colors.black87)),
                                if (hasEvents) Container(margin: const EdgeInsets.only(top: 2), width: 5, height: 5, decoration: BoxDecoration(color: isSelected ? Colors.white : const Color(0xFFF5A623), shape: BoxShape.circle)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Selected Day Shifts ─────────────────────
            Text(
              _selectedDay != null ? 'Details for ${_selectedDay!.day} $monthName' : 'Details',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            !hasShiftToday
                ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
              child: Column(
                children: [
                  Icon(Icons.event_available, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No shifts assigned for this date', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                ],
              ),
            )
                : Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.access_time_outlined, color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activeShift!['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text("${_activeShift!['startTime']} - ${_activeShift!['endTime']}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(50)),
                    child: const Text(
                      'Shift',
                      style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}