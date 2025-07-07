import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(child: Text("User not logged in"));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('blood_requests')
          .where('requestedBy', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'You have not made any blood requests yet.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Use the "Ask Blood" tab to create your first request.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;
            final isAccepted = data['acceptedBy'] != null;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${data['bloodGroup']} - ${data['units']} units',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isAccepted ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isAccepted ? Colors.green.shade200 : Colors.orange.shade200,
                            ),
                          ),
                          child: Text(
                            isAccepted ? 'ACCEPTED' : 'PENDING',
                            style: TextStyle(
                              color: isAccepted ? Colors.green.shade700 : Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.blue, size: 16),
                        const SizedBox(width: 4),
                        Text('City: ${data['city']}', style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                    if (data['timeUntil'] != null && data['timeUntil'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.orange, size: 16),
                            const SizedBox(width: 4),
                            Text('Time until: ${data['timeUntil']}', style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    if (data['notes'] != null && data['notes'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.note, color: Colors.purple, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text('Notes: ${data['notes']}', style: const TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                    if (isAccepted) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users') // Fixed: changed from 'profiles' to 'users'
                              .doc(data['acceptedBy'])
                              .get(),
                          builder: (context, donorSnapshot) {
                            if (donorSnapshot.connectionState == ConnectionState.waiting) {
                              return const Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
                                  Text("Loading donor info..."),
                                ],
                              );
                            }
                            if (!donorSnapshot.hasData || !donorSnapshot.data!.exists) {
                              return const Text("Donor info not available");
                            }

                            final donorData = donorSnapshot.data!.data() as Map<String, dynamic>;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.volunteer_activism, color: Colors.green, size: 16),
                                    SizedBox(width: 4),
                                    Text("Donor Information:", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.person, color: Colors.grey, size: 14),
                                    const SizedBox(width: 4),
                                    Text("Name: ${donorData['name'] ?? 'Unknown'}"),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, color: Colors.grey, size: 14),
                                    const SizedBox(width: 4),
                                    Text("Phone: ${donorData['phone'] ?? 'N/A'}"),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.grey, size: 14),
                                    const SizedBox(width: 4),
                                    Text("City: ${donorData['city'] ?? 'N/A'}"),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}