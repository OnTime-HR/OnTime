import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // Real-time stream subscription for the manager's shifts
  StreamSubscription? _shiftSubscription;
  List<Map<String, dynamic>> _myShifts = [];

  @override
  void initState() {
    super.initState();
    _listenToMyShifts();
  }

  @override
  void dispose() {
    _shiftSubscription?.cancel();
    super.dispose();
  }

  // --- DATA FETCHING & FILTERING ---
  void _listenToMyShifts() {
    if (_uid == null) return;

    _shiftSubscription = FirebaseFirestore.instance
        .collection('shifts')
        .snapshots()
        .listen((snapshot) {

      List<Map<String, dynamic>> activeShifts = [];

      // Loop through all shifts to find the ones assigned to THIS manager
      for (var doc in snapshot.docs) {
        var data = doc.data();
        if (data['assignedManagers'] != null) {
          List<dynamic> managers = data['assignedManagers'];

          for (var m in managers) {
            // Check if this map belongs to the current manager
            if (m is Map && m['id'] == _uid) {
              DateTime? sDate = DateTime.tryParse(m['startDate'] ?? '');
              DateTime? eDate = DateTime.tryParse(m['endDate'] ?? '');

              if (sDate != null && eDate != null) {
                activeShifts.add({
                  'id': doc.id,
                  'name': data['name'] ?? 'Assigned Shift',
                  'startTime': data['start_time'] ?? '--:--',
                  'endTime': data['end_time'] ?? '--:--',
                  'startDate': sDate,
                  'endDate': eDate,
                  'locationId': m['locationId'] ?? 'Unknown Location',
                });
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _myShifts = activeShifts;
        });
      }
    });
  }

  // --- DATE HELPERS ---
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isDateInRange(DateTime target, DateTime start, DateTime end) {
    // Strip times to ensure pure date comparison
    final t = DateTime(target.year, target.month, target.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return (t.isAfter(s) || _isSameDay(t, s)) && (t.isBefore(e) || _isSameDay(t, e));
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
    final calendarDays = _buildCalendarDays();
    final monthName = DateFormat('MMMM').format(_focusedMonth);

    // Get shifts for the currently selected day
    List<Map<String, dynamic>> todayShifts = [];
    if (_selectedDay != null) {
      todayShifts = _myShifts.where((shift) =>
          _isDateInRange(_selectedDay!, shift['startDate'], shift['endDate'])
      ).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calendar', style: TextStyle(color: Colors.grey, fontSize: 14)),
            Text('Your Schedule', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── 1. Monthly Calendar ────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                // Header (Month & Navigation)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$monthName ${_focusedMonth.year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Row(
                        children: [
                          IconButton(onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)), icon: const Icon(Icons.chevron_left), color: Colors.grey),
                          IconButton(onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)), icon: const Icon(Icons.chevron_right), color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                ),

                // Day Labels
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((d) => SizedBox(width: 36, child: Text(d, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade400)))).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Grid of Days
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, childAspectRatio: 1),
                    itemCount: calendarDays.length,
                    itemBuilder: (_, index) {
                      final day = calendarDays[index];
                      if (day == null) return const SizedBox();

                      final isToday = _isSameDay(day, DateTime.now());
                      final isSelected = _selectedDay != null && _isSameDay(day, _selectedDay!);

                      // Check if this specific day falls inside any of the user's shift date ranges
                      final hasEvents = _myShifts.any((shift) => _isDateInRange(day, shift['startDate'], shift['endDate']));

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
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : isToday ? const Color(0xFFF5A623) : Colors.black87,
                                ),
                              ),
                              if (hasEvents)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : const Color(0xFFF5A623),
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
          const SizedBox(height: 24),

          // ── 2. Display Assigned Shifts for Selected Day ─────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _selectedDay != null ? 'Schedule for ${_selectedDay!.day} $monthName' : 'Schedule',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: todayShifts.isEmpty
                ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_available, size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text('No schedule for this day', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                  ],
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: todayShifts.length,
              itemBuilder: (context, index) {
                var shift = todayShifts[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.access_time_filled, color: Colors.blue, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(shift['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text("${shift['startTime']} - ${shift['endTime']}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(shift['locationId'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}