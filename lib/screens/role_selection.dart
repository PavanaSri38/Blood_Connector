import 'package:flutter/material.dart';

class DonorDashboard extends StatelessWidget {
  const DonorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Donor Dashboard')),
      body: const Center(
        child: Text('Welcome, Donor! You can view and respond to requests here.'),
      ),
    );
  }
}
