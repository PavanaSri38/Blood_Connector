import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _userCity;
  String? _userBloodGroup;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _errorMessage = "User not logged in";
          _isLoading = false;
        });
        return;
      }

      print("Loading profile for user: $uid");

      // Try to get user profile
      final profileSnapshot = await _firestore.collection('users').doc(uid).get();

      if (profileSnapshot.exists) {
        final data = profileSnapshot.data()!;
        print("Profile data: $data");

        // Clean and normalize city - remove any extra parts like zip codes
        final rawCity = data['city']?.toString().trim();
        final city = _normalizeCity(rawCity);
        final bloodGroup = _extractBloodGroup(data['bloodGroup']?.toString());

        print("Raw city: $rawCity");
        print("Normalized city: $city");
        print("Extracted blood group: $bloodGroup");

        if (city == null || city.isEmpty) {
          setState(() {
            _errorMessage = "Please update your city in the Profile tab";
            _isLoading = false;
          });
          return;
        }

        if (bloodGroup == null || bloodGroup.isEmpty) {
          setState(() {
            _errorMessage = "Please update your blood group in the Profile tab";
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _userCity = city;
          _userBloodGroup = bloodGroup;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Profile not found. Please complete your profile in the Profile tab";
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
      setState(() {
        _errorMessage = "Error loading profile: $e";
        _isLoading = false;
      });
    }
  }

  /// Normalize city by removing zip codes and converting to lowercase
  String? _normalizeCity(String? rawCity) {
    if (rawCity == null || rawCity.isEmpty) return null;

    // Remove any numbers (zip codes) and extra whitespace
    final cleanCity = rawCity.replaceAll(RegExp(r'\s*\d+\s*'), '').trim().toLowerCase();
    return cleanCity.isEmpty ? null : cleanCity;
  }

  /// Extract short blood group format from full format
  String? _extractBloodGroup(String? fullBloodGroup) {
    if (fullBloodGroup == null || fullBloodGroup.isEmpty) return null;

    // Handle formats like "B Positive (B+)" -> "B+"
    final regex = RegExp(r'\(([^)]+)\)');
    final match = regex.firstMatch(fullBloodGroup);
    if (match != null) {
      return match.group(1)?.toUpperCase();
    }

    // Handle direct formats like "B+" or "b+"
    final directMatch = RegExp(r'^(A|B|AB|O)[+-]$', caseSensitive: false);
    if (directMatch.hasMatch(fullBloodGroup)) {
      return fullBloodGroup.toUpperCase();
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading your profile..."),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserProfile,
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Debug info bar (remove in production)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          color: Colors.blue.shade50,
          child: Text(
            "Looking for: $_userBloodGroup in $_userCity",
            style: const TextStyle(fontSize: 12, color: Colors.blue),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('blood_requests')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              print("🔍 Total requests in database: ${docs.length}");

              // Filter requests manually
              final matchingRequests = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final requestedBy = data['requestedBy'];
                final currentUserId = _auth.currentUser?.uid;
                final requestBloodGroup = data['bloodGroup']?.toString().toUpperCase();

                // Handle both 'city' and 'location' fields for backward compatibility
                final requestCity = _normalizeCity(
                    data['city']?.toString() ?? data['location']?.toString()
                );

                // Check if request has status field, if not assume it's pending
                final status = data['status']?.toString() ?? 'pending';

                print("🔍 Checking request: ${data['name']} - $requestBloodGroup in $requestCity (status: $status)");

                // Don't show own requests
                if (requestedBy == currentUserId) {
                  print("❌ Skipping own request");
                  return false;
                }

                // Only show pending requests
                if (status != 'pending') {
                  print("❌ Skipping non-pending request");
                  return false;
                }

                // Check blood group match
                if (requestBloodGroup != _userBloodGroup) {
                  print("❌ Blood group mismatch: $requestBloodGroup != $_userBloodGroup");
                  return false;
                }

                // Check city match
                if (requestCity != _userCity) {
                  print("❌ City mismatch: $requestCity != $_userCity");
                  return false;
                }

                print("✅ Matching request found: ${data['name']} - $requestBloodGroup in $requestCity");
                return true;
              }).toList();

              print("🎯 Matching requests after filtering: ${matchingRequests.length}");

              if (matchingRequests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No matching requests found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Looking for $_userBloodGroup requests in $_userCity',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                          });
                          _loadUserProfile();
                        },
                        child: const Text("Refresh"),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: matchingRequests.length,
                itemBuilder: (context, index) {
                  final data = matchingRequests[index].data() as Map<String, dynamic>;
                  final requestId = matchingRequests[index].id;

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
                              Expanded(
                                child: Text(
                                  '${data['name']} • ${data['bloodGroup']}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Text(
                                  'URGENT',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(Icons.water_drop, 'Units needed: ${data['units']}', Colors.red),
                          _buildInfoRow(Icons.location_on, 'Location: ${data['city'] ?? data['location']}', Colors.blue),
                          _buildInfoRow(Icons.phone, 'Contact: ${data['contact']}', Colors.green),
                          if (data['timeUntil'] != null && data['timeUntil'] != '')
                            _buildInfoRow(Icons.access_time, 'Time until: ${data['timeUntil']}', Colors.orange),
                          if (data['notes'] != null && data['notes'] != '')
                            _buildInfoRow(Icons.note, 'Notes: ${data['notes']}', Colors.purple),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _acceptRequest(requestId),
                              icon: const Icon(Icons.volunteer_activism),
                              label: const Text('Accept Request'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
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
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      await _firestore.collection('blood_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedBy': _auth.currentUser?.uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 You accepted the request! The requester will be notified.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error accepting request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}