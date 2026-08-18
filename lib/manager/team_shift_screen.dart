import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Required for formatting the dates

class TeamShiftScreen extends StatefulWidget {
  const TeamShiftScreen({super.key});

  @override
  State<TeamShiftScreen> createState() => _TeamShiftScreenState();
}

class _TeamShiftScreenState extends State<TeamShiftScreen> {
  String? selectedTeamId;
  String? selectedShiftId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool isSaving = false;

  // --- POP-UP NOTIFICATION HELPER ---
  void _showPopupMessage(String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? Colors.red : Colors.green,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                      color: isError ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isError ? Colors.red : Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- DATE RANGE PICKER ---
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      // Starts from today, allows scheduling up to 1 year in advance
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF39C12), // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Body text color
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _assignShiftToTeam() async {
    if (selectedTeamId == null || selectedShiftId == null || _startDate == null || _endDate == null) return;

    setState(() => isSaving = true);

    try {
      FirebaseFirestore db = FirebaseFirestore.instance;

      // 1. Find every user who belongs to this specific team
      var usersSnapshot = await db
          .collection('users')
          .where('teamId', isEqualTo: selectedTeamId)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() => isSaving = false);
          _showPopupMessage("Empty Team", "There are no employees currently assigned to this team.", isError: true);
        }
        return;
      }

      // 2. Create a Batch Write (updates everyone simultaneously)
      WriteBatch batch = db.batch();

      String formattedStart = DateFormat('yyyy-MM-dd').format(_startDate!);
      String formattedEnd = DateFormat('yyyy-MM-dd').format(_endDate!);

      for (var doc in usersSnapshot.docs) {
        batch.update(doc.reference, {
          'assignedShiftId': selectedShiftId,
          'shiftStartDate': formattedStart,
          'shiftEndDate': formattedEnd,
        });
      }

      // 3. Commit the batch to the database
      await batch.commit();

      if (mounted) {
        setState(() => isSaving = false);
        _showPopupMessage(
            "Shift Updated!",
            "Successfully assigned the shift to ${usersSnapshot.docs.length} employees from $formattedStart to $formattedEnd."
        );
        // Reset selections after success
        setState(() {
          selectedTeamId = null;
          selectedShiftId = null;
          _startDate = null;
          _endDate = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSaving = false);
        _showPopupMessage("Error", e.toString(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if all fields are filled to enable the save button
    bool canSave = selectedTeamId != null && selectedShiftId != null && _startDate != null && _endDate != null && !isSaving;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Shift Scheduler", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER CARD ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF39C12), Color(0xFFF1C40F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.groups_rounded, color: Colors.white, size: 40),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Team Assignments", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text("Update schedules for entire departments instantly.", style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // --- 1. SELECT TEAM DROPDOWN ---
              const Text('Select Target Team', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('teams')
                    .where('managerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.red.shade100)),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade400),
                          const SizedBox(width: 12),
                          const Expanded(child: Text("You have no teams assigned to you yet. Create teams in the database.", style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                  }

                  var teams = snapshot.data!.docs;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text("Choose a team"),
                        value: selectedTeamId,
                        icon: const Icon(Icons.expand_more, color: Colors.grey),
                        items: teams.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(data['name'] ?? 'Unnamed Team', style: const TextStyle(fontWeight: FontWeight.w500)),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => selectedTeamId = value),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),

              // --- 2. SELECT SHIFT DROPDOWN ---
              const Text('Assign Shift Schedule', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('shifts').get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                      child: const Text(
                        "No shifts have been created by admins yet.",
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    );
                  }

                  var shifts = snapshot.data!.docs;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade200)
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text("Choose a shift pattern"),
                        value: selectedShiftId,
                        icon: const Icon(Icons.expand_more, color: Colors.grey),
                        items: shifts.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          String start = data['start_time'] ?? '08:00';
                          String end = data['end_time'] ?? '17:00';

                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                                "${data['name'] ?? 'Unnamed Shift'} ($start - $end)",
                                style: const TextStyle(fontWeight: FontWeight.w500)
                            ),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => selectedShiftId = value),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),

              // --- 3. SELECT DATE RANGE ---
              const Text('Select Date Range', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              InkWell(
                onTap: _selectDateRange,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _startDate != null && _endDate != null
                              ? "${DateFormat('MMM dd, yyyy').format(_startDate!)}  to  ${DateFormat('MMM dd, yyyy').format(_endDate!)}"
                              : "Tap to select dates",
                          style: TextStyle(
                            color: _startDate != null ? Colors.black87 : Colors.grey.shade600,
                            fontWeight: _startDate != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (_startDate != null)
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 50),

              // --- 4. BULK SAVE BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: canSave ? _assignShiftToTeam : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF39C12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: canSave ? 4 : 0,
                  ),
                  child: isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Assign to Entire Team", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}