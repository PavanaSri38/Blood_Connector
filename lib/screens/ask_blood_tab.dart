import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AskBloodTab extends StatefulWidget {
  const AskBloodTab({super.key});

  @override
  State<AskBloodTab> createState() => _AskBloodTabState();
}

class _AskBloodTabState extends State<AskBloodTab> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final cityController = TextEditingController();
  final contactController = TextEditingController();
  final unitsController = TextEditingController();
  final timeUntilController = TextEditingController();
  final notesController = TextEditingController();

  String selectedBloodGroup = 'A+';
  final List<String> bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  void submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to submit a request")),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('blood_requests').add({
        'name': nameController.text.trim(),
        'age': int.tryParse(ageController.text) ?? 0,
        'city': cityController.text.trim().toLowerCase(),
        'bloodGroup': selectedBloodGroup.trim().toUpperCase(),
        'contact': contactController.text.trim(),
        'units': int.tryParse(unitsController.text) ?? 1,
        'timeUntil': timeUntilController.text.trim(),
        'notes': notesController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'requestedBy': user.uid,
        'status': 'pending',
        'acceptedBy': null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Request submitted successfully!"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _formKey.currentState!.reset();
      setState(() => selectedBloodGroup = 'A+');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            const Text(
              'Request Blood',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: nameController,
              label: 'Full Name',
              icon: Icons.person,
              validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildTextField(
                    controller: ageController,
                    label: 'Age',
                    icon: Icons.cake,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value!.isEmpty) return 'Please enter age';
                      if (int.tryParse(value) == null) return 'Enter valid number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: selectedBloodGroup,
                    decoration: InputDecoration(
                      labelText: 'Blood Group',
                      prefixIcon: const Icon(Icons.bloodtype),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: bloodGroups.map((bg) => DropdownMenuItem(
                      value: bg,
                      child: Text(bg, style: const TextStyle(fontSize: 16)),
                    )).toList(),
                    onChanged: (value) => setState(() => selectedBloodGroup = value!),
                    validator: (value) => value == null ? 'Select blood group' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: cityController,
              label: 'City',
              icon: Icons.location_city,
              validator: (value) => value!.isEmpty ? 'Please enter your city' : null,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: contactController,
              label: 'Contact Number',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value!.isEmpty) return 'Please enter contact number';
                if (value.length < 10) return 'Enter valid number';
                return null;
              },
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: unitsController,
                    label: 'Units Needed',
                    icon: Icons.bloodtype_outlined,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value!.isEmpty) return 'Enter units needed';
                      if (int.tryParse(value) == null) return 'Enter valid number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildTextField(
                    controller: timeUntilController,
                    label: 'Time Until',
                    icon: Icons.access_time,
                    validator: (value) => value!.isEmpty ? 'Please specify time' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: notesController,
              label: 'Additional Notes',
              icon: Icons.note,
              maxLines: 3,
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 3,
              ),
              child: const Text(
                'SUBMIT REQUEST',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
    );
  }
}