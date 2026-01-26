import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/index.dart';

class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({super.key});

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return DoctorScaffold(
      pageTitle: '@ Doctor Dashboard',
      currentNavIndex: _currentNavIndex,
      onNavChanged: (index) {
        setState(() => _currentNavIndex = index);
        // Navigate to different pages based on index
        switch (index) {
          case 0:
            // Dashboard - already here
            break;
          case 1:
            // Patients
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Navigating to Patients')),
            );
            break;
          case 2:
            // Schedule
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Navigating to Schedule')),
            );
            break;
          case 3:
            // Settings
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Navigating to Settings')),
            );
            break;
        }
      },
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Doctor Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            _DashboardCard(
              icon: Icons.people,
              title: 'Total Patients',
              count: '24',
            ),
            const SizedBox(height: 12),
            _DashboardCard(
              icon: Icons.calendar_today,
              title: 'Appointments Today',
              count: '5',
            ),
            const SizedBox(height: 12),
            _DashboardCard(
              icon: Icons.pending_actions,
              title: 'Pending Tasks',
              count: '3',
            ),
            const SizedBox(height: 12),
            _DashboardCard(
              icon: Icons.description,
              title: 'Reports to Review',
              count: '7',
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String count;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: const Color(0xFFE91E63),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      count,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
