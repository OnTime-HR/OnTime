import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class ShiftCalendarScreen extends StatefulWidget {
  const ShiftCalendarScreen({super.key});

  @override
  State<ShiftCalendarScreen> createState() => _ShiftCalendarScreenState();
}

class _ShiftCalendarScreenState extends State<ShiftCalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  String? _companyCode;
  String? _employeePhone;
  bool _isLoadingUserData = true;

  List<Map<String, dynamic>> _selectedDayEntries = [];
  List<String> _datesWithEvents = [];

  StreamSubscription? _dayEntriesSub;
  StreamSubscription? _monthEventsSub;

  @override
  void initState() {
    super.initState();
    _fetchEmployeeData();
  }

  @override
  void dispose() {
    _dayEntriesSub?.cancel();
    _monthEventsSub?.cancel();
    super.dispose();
  }

  // 1. Get the employee's company code and phone to filter their specific shifts
  Future<void> _fetchEmployeeData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _companyCode = doc.data()?['company_code'];
            _employeePhone = doc.data()?['phone'];
            _isLoadingUserData = false;
          });

          if (_companyCode != null && _employeePhone != null) {
            _loadMonthEvents();
            _loadDayEntries(_selectedDay ?? DateTime.now());
          }
        }
      } catch (e) {
        debugPrint("Error fetching user data: $e");
        if (mounted) setState(() => _isLoadingUserData = false);
      }
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  bool _hasEvents(DateTime day) => _datesWithEvents.contains(_dateKey(day));

  // 2. Load dates that have ANY events (to show the little dot on the calendar)
  void _loadMonthEvents() {
    if (_companyCode == null) return;
    _monthEventsSub?.cancel();

    final prefix = '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}';

    _monthEventsSub = FirebaseFirestore.instance
        .collection('schedules')
        .doc(_companyCode)
        .collection('days')
        .snapshots()
        .map((snap) => snap.docs
        .where((doc) => doc.id.startsWith(prefix))
        .map((doc) => doc.id)
        .toList())
        .listen((dates) {
      if (mounted) setState(() => _datesWithEvents = dates);
    });
  }

  // 3. Load entries for the selected day, FILTERED by this employee's phone
  void _loadDayEntries(DateTime date) {
    if (_companyCode == null || _employeePhone == null) return;
    _dayEntriesSub?.cancel();

    _dayEntriesSub = FirebaseFirestore.instance
        .collection('schedules')
        .doc(_companyCode)
        .collection('days')
        .doc(_dateKey(date))
        .collection('entries')
        .where('employeePhone', isEqualTo: _employeePhone) // ONLY THIS EMPLOYEE
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _selectedDayEntries = snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        });
      }
    });
  }

  void _previousMonth() {
    setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1));
    _loadMonthEvents();
  }

  void _nextMonth() {
    setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1));
    _loadMonthEvents();
  }

  List<DateTime?> _buildCalendarDays() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // 0 = Sunday

    final days = <DateTime?>[];
    for (int i = 0; i < startWeekday; i++) days.add(null);
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(_focusedMonth.year, _focusedMonth.month, i));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUserData) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFF39C12))),
      );
    }

    final calendarDays = _buildCalendarDays();
    final monthName = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][_focusedMonth.month - 1];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Shift Calendar",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Monthly Calendar ────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$monthName ${_focusedMonth.year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
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
                            (d) => SizedBox(width: 36, child: Text(d, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade500))),
                      ).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 4, childAspectRatio: 1),
                      itemCount: calendarDays.length,
                      itemBuilder: (_, index) {
                        final day = calendarDays[index];
                        if (day == null) return const SizedBox();

                        final isToday = day.year == DateTime.now().year && day.month == DateTime.now().month && day.day == DateTime.now().day;
                        final isSelected = _selectedDay != null && day.year == _selectedDay!.year && day.month == _selectedDay!.month && day.day == _selectedDay!.day;
                        final hasEvents = _hasEvents(day);

                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedDay = day);
                            _loadDayEntries(day);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFF39C12) : isToday ? const Color(0xFFFFF8ED) : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${day.day}', style: TextStyle(fontSize: 14, fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : isToday ? const Color(0xFFD97706) : Colors.black87)),
                                if (hasEvents)
                                  Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                          color: isSelected ? Colors.white : const Color(0xFFF39C12),
                                          shape: BoxShape.circle
                                      )
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // ── Selected Day Shifts ─────────────────────
            Text(
              _selectedDay != null ? 'Schedule for ${_selectedDay!.day} $monthName' : 'Your Schedule',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _selectedDayEntries.isEmpty
                ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  Icon(Icons.event_available, size: 50, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No shifts or leaves scheduled', style: TextStyle(color: Colors.grey.shade500, fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            )
                : Column(
              children: _selectedDayEntries.map((event) {
                final isLeave = event['type'] == 'leave';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isLeave ? const Color(0xFFFFF8ED) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isLeave ? const Color(0xFFFDE68A) : Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: isLeave ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14)
                        ),
                        child: Icon(
                            isLeave ? Icons.beach_access_rounded : Icons.work_history_rounded,
                            color: isLeave ? const Color(0xFFF39C12) : Colors.blue,
                            size: 24
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLeave ? 'Approved Leave' : 'Assigned Shift',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(event['detail'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: isLeave ? const Color(0xFFF39C12) : Colors.blue,
                            borderRadius: BorderRadius.circular(30)
                        ),
                        child: Text(
                          isLeave ? 'Leave' : 'Shift',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}