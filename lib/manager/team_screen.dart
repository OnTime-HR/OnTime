import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:ontime/manager/team_detail_screen.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isProcessingCSV = false;
  final String? _currentManagerId = FirebaseAuth.instance.currentUser?.uid;

  void _showPopupMessage(String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: isError ? Colors.red : Colors.green, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TextStyle(color: isError ? Colors.red : Colors.green, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4)),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isError ? Colors.red : Colors.green),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showCreateTeamDialog() {
    TextEditingController teamNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Create New Team", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: teamNameController,
          decoration: InputDecoration(
            hintText: "e.g. Frontend Developers",
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF39C12)),
            onPressed: () async {
              if (teamNameController.text.trim().isEmpty) return;
              Navigator.pop(ctx);

              if (_currentManagerId != null) {
                await FirebaseFirestore.instance.collection('teams').add({
                  'name': teamNameController.text.trim(),
                  'managerId': _currentManagerId,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                _showPopupMessage("Success", "Team created successfully!");
              }
            },
            child: const Text("Create", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkUploadTeamsCSV() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) return;

      setState(() => _isProcessingCSV = true);

      final input = File(result.files.single.path!).openRead();
      final fields = await input.transform(utf8.decoder).transform(const CsvToListConverter()).toList();

      if (fields.length <= 1) throw Exception("The CSV file is empty or missing data rows.");

      int successCount = 0;
      int skippedCount = 0;
      FirebaseFirestore db = FirebaseFirestore.instance;

      for (int i = 1; i < fields.length; i++) {
        var row = fields[i];
        if (row.length < 2) continue;

        String rawPhone = row[0].toString().trim();
        String phone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
        String targetTeamName = row[1].toString().trim();

        if (phone.isEmpty || targetTeamName.isEmpty) continue;

        var preAuthDoc = await db.collection('pre_authorized_users').doc(phone).get();
        if (!preAuthDoc.exists) {
          skippedCount++;
          continue;
        }

        var teamQuery = await db.collection('teams')
            .where('managerId', isEqualTo: _currentManagerId)
            .where('name', isEqualTo: targetTeamName)
            .limit(1)
            .get();

        String teamId;
        if (teamQuery.docs.isEmpty) {
          var newTeam = await db.collection('teams').add({
            'name': targetTeamName,
            'managerId': _currentManagerId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          teamId = newTeam.id;
        } else {
          teamId = teamQuery.docs.first.id;
        }

        await db.collection('pre_authorized_users').doc(phone).update({'teamId': teamId});

        var userQuery = await db.collection('users').where('phone', isEqualTo: phone).limit(1).get();
        if (userQuery.docs.isNotEmpty) {
          await db.collection('users').doc(userQuery.docs.first.id).update({'teamId': teamId});
        }
        successCount++;
      }

      setState(() => _isProcessingCSV = false);

      String feedbackMessage = "Successfully assigned $successCount employees to their teams.";
      if (skippedCount > 0) feedbackMessage += "\n\nSecurity Notice: $skippedCount rows were skipped because the phone numbers were not found in the authorized users list.";

      _showPopupMessage("Upload Complete", feedbackMessage, isError: skippedCount > 0 && successCount == 0);

    } catch (e) {
      setState(() => _isProcessingCSV = false);
      _showPopupMessage("Upload Error", "Failed to process CSV file: ${e.toString()}", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Departments', style: TextStyle(color: Colors.grey, fontSize: 14)),
            Text('Your Teams', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // --- NEW BUTTON LAYOUT ---
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade700,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showCreateTeamDialog,
                        icon: const Icon(Icons.add_box_outlined, size: 20),
                        label: const Text("New Team", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _isProcessingCSV
                          ? const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.green)))
                          : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade50,
                          foregroundColor: Colors.green.shade700,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _bulkUploadTeamsCSV,
                        icon: const Icon(Icons.file_upload_outlined, size: 20),
                        label: const Text("Bulk Assign", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // --- SEARCH BAR ---
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(50), border: Border.all(color: Colors.grey.shade200)),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search teams...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stream the Manager's Teams
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('teams').where('managerId', isEqualTo: _currentManagerId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFF39C12)));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text("You don't have any teams yet.", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                      ],
                    ),
                  );
                }

                var teams = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery.toLowerCase());
                }).toList();

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: teams.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    var teamDoc = teams[i];
                    var teamData = teamDoc.data() as Map<String, dynamic>;
                    String teamName = teamData['name'] ?? 'Unnamed Team';

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => TeamDetailScreen(teamId: teamDoc.id, teamName: teamName)));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.groups_rounded, color: Color(0xFFF39C12), size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(teamName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(height: 4),
                                  Text("Tap to view and manage members", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}