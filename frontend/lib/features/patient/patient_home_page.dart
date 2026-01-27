import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/index.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return PatientScaffold(
      pageTitle: '@ Patient Home',
      currentNavIndex: _currentNavIndex,
      onNavChanged: (index) {
        setState(() => _currentNavIndex = index);
        // Navigate to different pages based on index
        switch (index) {
          case 0:
            // Home - already here
            break;
          case 1:
            Navigator.of(context).pushReplacementNamed('/patient-update-inr');
            break;
          case 2:
            Navigator.of(context).pushReplacementNamed('/patient-take-dosage');
            break;
          case 3:
            Navigator.of(context).pushReplacementNamed('/patient-profile');
            break;
        }
      },
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome to Patient Portal',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            _QuickAccessCard(
              icon: Icons.calendar_today,
              title: 'Upcoming Appointments',
              subtitle: 'No upcoming appointments',
            ),
            const SizedBox(height: 12),
            _QuickAccessCard(
              icon: Icons.description,
              title: 'Medical Records',
              subtitle: 'View your health records',
            ),
            const SizedBox(height: 12),
            _QuickAccessCard(
              icon: Icons.message,
              title: 'Messages',
              subtitle: '0 unread messages',
            ),
            const SizedBox(height: 12),
            _QuickAccessCard(
              icon: Icons.medication,
              title: 'Prescriptions',
              subtitle: 'Active prescriptions',
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0xFFE91E63),
          size: 28,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}
