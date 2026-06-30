import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Needed to fetch the manager's teams

class AssignLocationScreen extends StatefulWidget {
  const AssignLocationScreen({super.key});

  @override
  State<AssignLocationScreen> createState() => _AssignLocationScreenState();
}

class _AssignLocationScreenState extends State<AssignLocationScreen> {
  String? selectedTeamId; // Changed from selectedUserId to selectedTeamId
  String? selectedBranchId;
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
                child: Text(
                  title,
                  style: TextStyle(
                    color: isError ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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

  // --- BATCH ASSIGN LOCATION TO ENTIRE TEAM ---
  void _assignLocationToTeam() async {
    if (selectedTeamId == null || selectedBranchId == null) return;

    setState(() => isSaving = true);

    try {
      FirebaseFirestore db = FirebaseFirestore.instance;

      // 1. Find all users in the selected team
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

      // 2. Create a batch write to update all employees at once
      WriteBatch batch = db.batch();

      for (var doc in usersSnapshot.docs) {
        batch.update(doc.reference, {'assignedOfficeId': selectedBranchId});
      }

      // 3. Commit the batch
      await batch.commit();

      if (mounted) {
        setState(() => isSaving = false);
        _showPopupMessage(
            "Success",
            "Work location successfully assigned to ${usersSnapshot.docs.length} employees."
        );
        setState(() {
          selectedTeamId = null;
          selectedBranchId = null;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Location Assignment", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF39C12), Color(0xFFF1C40F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: Colors.white, size: 40),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Geofence Setup", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text("Map entire teams to authorized enterprise operational perimeters.", style: TextStyle(color: Colors.white70, fontSize: 13)),
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

              // --- 2. SELECT BRANCH DROPDOWN ---
              const Text('Assign to Branch', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('offices').get(),
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
                          const Expanded(child: Text("No operating branches found in the database system.", style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                  }

                  var branches = snapshot.data!.docs;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text("Choose an operating location"),
                        value: selectedBranchId,
                        icon: const Icon(Icons.expand_more, color: Colors.grey),
                        items: branches.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(data['name'] ?? doc.id, style: const TextStyle(fontWeight: FontWeight.w500)),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => selectedBranchId = value),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 50),

              // --- 3. SAVE ASSIGNMENT BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: (selectedTeamId == null || selectedBranchId == null || isSaving) ? null : _assignLocationToTeam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF39C12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: (selectedTeamId == null || selectedBranchId == null) ? 0 : 4,
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