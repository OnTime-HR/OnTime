import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ShiftCalendarScreen extends StatefulWidget {
  final VoidCallback? onBack; // Required for the indexed stack navigation

  const ShiftCalendarScreen({super.key, this.onBack});

  @override
  State<ShiftCalendarScreen> createState() => _ShiftCalendarScreenState();
}

class _ShiftCalendarScreenState extends State<ShiftCalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  String? _currentUserRole;
  bool _isLoadingData = true;

  // Store the user's default shift details
  String _shiftName = "Standard Shift";
  String _shiftTime = "08:30 AM - 05:30 PM";

  // Data storage for fast calendar rendering
  final Map<String, Map<String, dynamic>> _attendanceHistory = {};
  final Map<String, Map<String, dynamic>> _approvedLeaves = {};

  List<Map<String, dynamic>> _selectedDayEntries = [];

  @override
  void initState() {
    super.initState();
    _fetchAllCalendarData();
  }

  // --- 1. FETCH ALL DATA AT ONCE ---
  Future<void> _fetchAllCalendarData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      FirebaseFirestore db = FirebaseFirestore.instance;

      // A. Fetch User Profile & Shift Template
      var userDoc = await db.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        _currentUserRole = userDoc.data()?['role'];
        String? shiftId = userDoc.data()?['assignedShiftId'];

        if (shiftId != null) {
          var shiftDoc = await db.collection('shifts').doc(shiftId).get();
          if (shiftDoc.exists) {
            _shiftName = shiftDoc.data()?['name'] ?? "Standard Shift";
            _shiftTime = "${shiftDoc.data()?['startTime']} - ${shiftDoc.data()?['endTime']}";
          }
        }
      }

      // B. Fetch Attendance History (Past completed shifts)
      var attendanceDocs = await db.collection('users').doc(user.uid).collection('attendance').get();
      for (var doc in attendanceDocs.docs) {
        _attendanceHistory[doc.id] = doc.data(); // doc.id is 'yyyy-MM-dd'
      }

      // C. Fetch Approved Leaves
      var leaveDocs = await db.collection('leave_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'Approved')
          .get();

      for (var doc in leaveDocs.docs) {
        var data = doc.data();
        DateTime start = (data['startDate'] as Timestamp).toDate();
        DateTime end = (data['endDate'] as Timestamp).toDate();

        // Populate every day in the leave range
        for (int i = 0; i <= end.difference(start).inDays; i++) {
          DateTime leaveDay = start.add(Duration(days: i));
          _approvedLeaves[_dateKey(leaveDay)] = data;
        }
      }

      if (mounted) {
        setState(() => _isLoadingData = false);
        _generateDayEntries(_selectedDay ?? DateTime.now());
      }
    } catch (e) {
      debugPrint("Error fetching calendar data: $e");
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  // --- 2. DETERMINE IF A DOT SHOULD SHOW ON THE CALENDAR ---
  bool _hasEvents(DateTime day) {
    String key = _dateKey(day);

    // Show dot if they worked that day (History)
    if (_attendanceHistory.containsKey(key)) return true;

    // Show dot if they are on leave
    if (_approvedLeaves.containsKey(key)) return true;

    // Show dot if it's an upcoming weekday (Future Shift)
    DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    DateTime checkDay = DateTime(day.year, day.month, day.day);
    if (checkDay.isAfter(today) || checkDay.isAtSameMomentAs(today)) {
      if (day.weekday != DateTime.saturday && day.weekday != DateTime.sunday) {
        return true;
      }
    }
    return false;
  }

  // --- 3. GENERATE THE LIST OF EVENTS FOR THE SELECTED DAY ---
  void _generateDayEntries(DateTime date) {
    String key = _dateKey(date);
    List<Map<String, dynamic>> entries = [];

    // 1. Check for Leaves
    if (_approvedLeaves.containsKey(key)) {
      entries.add({
        'type': 'leave',
        'title': 'Approved Leave',
        'detail': _approvedLeaves[key]!['leaveType'] ?? 'Time Off'
      });
    }
    // 2. Check for Attendance History (Past)
    else if (_attendanceHistory.containsKey(key)) {
      var data = _attendanceHistory[key]!;
      String checkIn = data['checkInTime'] ?? '--:--';
      String checkOut = data['checkOutTime'] ?? 'Missed Punch';
      String totalTime = data['totalWorkingTime'] ?? 'Unknown';

      entries.add({
        'type': 'history',
        'title': 'Shift Completed',
        'detail': 'In: $checkIn | Out: $checkOut\nTotal Time: $totalTime'
      });
    }
    // 3. Check for Upcoming Shifts (Today or Future Weekday)
    else {
      DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      DateTime checkDay = DateTime(date.year, date.month, date.day);

      if ((checkDay.isAfter(today) || checkDay.isAtSameMomentAs(today)) &&
          date.weekday != DateTime.saturday &&
          date.weekday != DateTime.sunday) {
        entries.add({
          'type': 'shift',
          'title': 'Upcoming: $_shiftName',
          'detail': _shiftTime
        });
      }
    }

    setState(() {
      _selectedDayEntries = entries;
    });
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
    for (int i = 0; i < startWeekday; i++) days.add(null);
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(_focusedMonth.year, _focusedMonth.month, i));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFF39C12))),
      );
    }

    final calendarDays = _buildCalendarDays();
    final monthName = DateFormat('MMMM').format(_focusedMonth);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.onBack != null
            ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: widget.onBack,
        )
            : null,
        title: const Text(
          "Schedule & History",
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
                            _generateDayEntries(day);
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

            // ── Selected Day Details ─────────────────────
            Text(
              _selectedDay != null ? 'Details for ${_selectedDay!.day} $monthName' : 'Schedule Details',
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
                  Icon(Icons.event_busy, size: 50, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No shifts or history on this day.', style: TextStyle(color: Colors.grey.shade500, fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            )
                : Column(
              children: _selectedDayEntries.map((event) {
                final isLeave = event['type'] == 'leave';
                final isHistory = event['type'] == 'history';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isLeave ? const Color(0xFFFFF8ED) : isHistory ? Colors.green.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isLeave ? const Color(0xFFFDE68A) : isHistory ? Colors.green.shade200 : Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: isLeave ? Colors.orange.withOpacity(0.1) : isHistory ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14)
                        ),
                        child: Icon(
                            isLeave ? Icons.beach_access_rounded : isHistory ? Icons.check_circle_outline : Icons.work_history_rounded,
                            color: isLeave ? const Color(0xFFF39C12) : isHistory ? Colors.green : Colors.blue,
                            size: 24
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event['title'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(event['detail'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: isLeave ? const Color(0xFFF39C12) : isHistory ? Colors.green : Colors.blue,
                            borderRadius: BorderRadius.circular(30)
                        ),
                        child: Text(
                          isLeave ? 'Leave' : isHistory ? 'History' : 'Upcoming',
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