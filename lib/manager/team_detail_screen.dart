import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeamDetailScreen extends StatefulWidget {
  final String teamId;
  final String teamName;

  const TeamDetailScreen({super.key, required this.teamId, required this.teamName});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  final String? _currentManagerId = FirebaseAuth.instance.currentUser?.uid;

  // --- FILTER STATE ---
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Present', 'On Leave'];

  Color _statusColor(String status) => status == 'Present' ? Colors.green : Colors.orange;
  Color _statusBgColor(String status) => status == 'Present' ? Colors.green.shade50 : Colors.orange.shade50;

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

  Future<void> _removeMember(String userId, String userName) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Member?", style: TextStyle(color: Colors.red)),
        content: Text("Are you sure you want to remove $userName from ${widget.teamName}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Remove", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({'teamId': 'unassigned'});
        if (mounted) _showPopupMessage("Removed", "$userName has been successfully removed from the team.");
      } catch (e) {
        if (mounted) _showPopupMessage("Error", "Failed to remove member: $e", isError: true);
      }
    }
  }

  Future<void> _reassignMember(String userId, String userName) async {
    var teamsSnapshot = await FirebaseFirestore.instance
        .collection('teams')
        .where('managerId', isEqualTo: _currentManagerId)
        .get();

    var otherTeams = teamsSnapshot.docs.where((doc) => doc.id != widget.teamId).toList();

    if (otherTeams.isEmpty && mounted) {
      _showPopupMessage("No Teams Available", "You don't have any other teams to reassign this employee to.", isError: true);
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reassign Member", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: otherTeams.length,
            itemBuilder: (context, index) {
              var teamData = otherTeams[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.swap_horiz, color: Colors.blue),
                ),
                title: Text(teamData['name'] ?? 'Unknown Team', style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await FirebaseFirestore.instance.collection('users').doc(userId).update({'teamId': otherTeams[index].id});
                    if (mounted) _showPopupMessage("Reassigned", "$userName successfully reassigned to ${teamData['name']}.");
                  } catch (e) {
                    if (mounted) _showPopupMessage("Error", "Failed to reassign member: $e", isError: true);
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAddMemberDialog() {
    TextEditingController phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add Member to Team", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: "Enter employee phone number",
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.phone, color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF39C12)),
            onPressed: () async {
              String rawPhone = phoneController.text.trim();
              String phone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
              if (phone.isEmpty) return;

              Navigator.pop(ctx);

              FirebaseFirestore db = FirebaseFirestore.instance;

              try {
                var preAuthDoc = await db.collection('pre_authorized_users').doc(phone).get();

                if (!preAuthDoc.exists) {
                  if (mounted) _showPopupMessage("Unauthorized Number", "The number $phone is not in the company's authorized list. Please verify the number.", isError: true);
                  return;
                }

                await db.collection('pre_authorized_users').doc(phone).update({'teamId': widget.teamId});

                var userQuery = await db.collection('users').where('phone', isEqualTo: phone).limit(1).get();
                if (userQuery.docs.isNotEmpty) {
                  await db.collection('users').doc(userQuery.docs.first.id).update({'teamId': widget.teamId});
                }

                if (mounted) _showPopupMessage("Success", "Employee successfully added to ${widget.teamName}!");

              } catch (e) {
                if (mounted) _showPopupMessage("Error", "Failed to add member: $e", isError: true);
              }
            },
            child: const Text("Add Member", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- HELPER FOR MINI STATS ---
  Widget _buildMiniStat(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: Text(widget.teamName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Color(0xFFF39C12)),
            onPressed: _showAddMemberDialog,
            tooltip: "Add Member",
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').where('teamId', isEqualTo: widget.teamId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFF39C12)));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("No active members in this team yet.", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text("Tap the + icon to add employees.", style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                ],
              ),
            );
          }

          var allMembers = snapshot.data!.docs;

          // 1. Calculate stats dynamically
          int presentCount = 0;
          int leaveCount = 0;

          for (var doc in allMembers) {
            var data = doc.data() as Map<String, dynamic>;
            String status = data['status'] ?? 'On Leave';
            if (status == 'Absent') status = 'On Leave';

            if (status == 'Present') {
              presentCount++;
            } else {
              leaveCount++;
            }
          }

          // 2. Filter the list based on the selected chip
          var displayedMembers = allMembers.where((doc) {
            if (_selectedFilter == 'All') return true;

            var data = doc.data() as Map<String, dynamic>;
            String status = data['status'] ?? 'On Leave';
            if (status == 'Absent') status = 'On Leave';

            return status == _selectedFilter;
          }).toList();

          return Column(
            children: [
              // --- STATS & FILTERS HEADER ---
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildMiniStat('Present', presentCount, Colors.green),
                        const SizedBox(width: 16),
                        _buildMiniStat('On Leave', leaveCount, Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final f = _filters[i];
                          final selected = _selectedFilter == f;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedFilter = f),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFFF39C12) : Colors.white,
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(color: selected ? const Color(0xFFF39C12) : Colors.grey.shade200),
                              ),
                              child: Text(
                                f,
                                style: TextStyle(color: selected ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // --- EMPLOYEE LIST ---
              Expanded(
                child: displayedMembers.isEmpty
                    ? Center(child: Text("No members matching '$_selectedFilter'", style: TextStyle(color: Colors.grey.shade500)))
                    : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: displayedMembers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    var userDoc = displayedMembers[i];
                    var userData = userDoc.data() as Map<String, dynamic>;
                    String name = userData['name'] ?? 'Unknown';
                    String role = userData['role'] ?? 'Employee';
                    String status = userData['status'] ?? 'On Leave';
                    if (status == 'Absent') status = 'On Leave';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.orange.shade100,
                            child: Text(name[0].toUpperCase(), style: const TextStyle(color: Color(0xFFF39C12), fontWeight: FontWeight.bold, fontSize: 18)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(role, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: _statusBgColor(status), borderRadius: BorderRadius.circular(50)),
                            child: Text(status, style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w600, fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            onSelected: (value) {
                              if (value == 'reassign') _reassignMember(userDoc.id, name);
                              if (value == 'remove') _removeMember(userDoc.id, name);
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(value: 'reassign', child: Text('Reassign Team')),
                              const PopupMenuItem<String>(value: 'remove', child: Text('Remove from Team', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}