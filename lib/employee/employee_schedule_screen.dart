import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
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
        setState(() => _isLoadingUserData = false);
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

    final prefix =
        '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}';

    _monthEventsSub = FirebaseFirestore.instance
        .collection('schedules')
        .doc(_companyCode)
        .collection('days')
        .snapshots()
        .map(
          (snap) => snap.docs
              .where((doc) => doc.id.startsWith(prefix))
              .map((doc) => doc.id)
              .toList(),
        )
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
              _selectedDayEntries = snap.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList();
            });
          }
        });
  }

  void _previousMonth() {
    setState(
      () =>
          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1),
    );
    _loadMonthEvents();
  }

  void _nextMonth() {
    setState(
      () =>
          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1),
    );
    _loadMonthEvents();
  }

  List<DateTime?> _buildCalendarDays() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7;

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
        backgroundColor: Color(0xFFF8F9FB),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF5A623)),
        ),
      );
    }

    final calendarDays = _buildCalendarDays();
    final monthName = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][_focusedMonth.month - 1];

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
            Text(
              'Calendar',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            Text(
              'My Schedule',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Monthly Calendar (Matches Manager View) ────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$monthName ${_focusedMonth.year}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _previousMonth,
                              icon: const Icon(Icons.chevron_left),
                              color: Colors.grey,
                            ),
                            IconButton(
                              onPressed: _nextMonth,
                              icon: const Icon(Icons.chevron_right),
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children:
                          ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                              .map(
                                (d) => SizedBox(
                                  width: 36,
                                  child: Text(
                                    d,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 0,
                            childAspectRatio: 1,
                          ),
                      itemCount: calendarDays.length,
                      itemBuilder: (_, index) {
                        final day = calendarDays[index];
                        if (day == null) return const SizedBox();

                        final isToday =
                            day.year == DateTime.now().year &&
                            day.month == DateTime.now().month &&
                            day.day == DateTime.now().day;
                        final isSelected =
                            _selectedDay != null &&
                            day.year == _selectedDay!.year &&
                            day.month == _selectedDay!.month &&
                            day.day == _selectedDay!.day;
                        final hasEvents = _hasEvents(day);

                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedDay = day);
                            _loadDayEntries(day);
                          },
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFF5A623)
                                  : isToday
                                  ? const Color(0xFFFFF3E0)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isToday || isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.white
                                        : isToday
                                        ? const Color(0xFFF5A623)
                                        : Colors.black87,
                                  ),
                                ),
                                if (hasEvents)
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFFF5A623),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
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
              _selectedDay != null
                  ? 'Details for ${_selectedDay!.day} $monthName'
                  : 'Details',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _selectedDayEntries.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 40,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You have no shifts or leaves on this day',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: _selectedDayEntries.map((event) {
                      final isLeave = event['type'] == 'leave';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isLeave
                                    ? Colors.orange.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isLeave
                                    ? Icons.beach_access_outlined
                                    : Icons.access_time_outlined,
                                color: isLeave ? Colors.orange : Colors.blue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isLeave
                                        ? 'Approved Leave'
                                        : 'Assigned Shift',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    event['detail'] ?? '',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isLeave
                                    ? Colors.orange.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Text(
                                isLeave ? 'Leave' : 'Shift',
                                style: TextStyle(
                                  color: isLeave ? Colors.orange : Colors.blue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
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
