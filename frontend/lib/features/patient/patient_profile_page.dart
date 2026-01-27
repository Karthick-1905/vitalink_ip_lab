import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/index.dart';

class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key});

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  int _currentNavIndex = 3;

  // Mock patient data
  final Map<String, dynamic> _patientData = {
    'name': 'Surya Narayanaa',
    'age': 20,
    'gender': 'Male',
    'phone': '+91-98765-43210',
    'opNumber': 'OP #: 12345',
    'therapyDrug': 'Warfarin',
    'therapyStartDate': '15-06-2023',
    'targetINR': '8 - 5',
    'nextReviewDate': '22-10-2025',
    'doctor': {
      'name': 'Dr. Rajesh Kumar',
      'specialty': 'Cardiology',
      'phone': '+91-98765-54321',
      'email': 'rajesh.kumar@hospital.com',
    },
  };

  @override
  Widget build(BuildContext context) {
    return PatientScaffold(
      pageTitle: '@ Profile',
      currentNavIndex: _currentNavIndex,
      onNavChanged: (index) {
        switch (index) {
          case 0:
            Navigator.of(context).pushReplacementNamed('/patient-home');
            break;
          case 1:
            Navigator.of(context).pushReplacementNamed('/patient-update-inr');
            break;
          case 2:
            Navigator.of(context).pushReplacementNamed('/patient-take-dosage');
            break;
          case 3:
            // Already on profile
            break;
        }
      },
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Basic Information Section
            _buildSection(
              title: 'Basic Information',
              children: [
                _buildDetailRow('Name', _patientData['name']),
                _buildDetailRow('Age', '${_patientData['age']} years'),
                _buildDetailRow('Gender', _patientData['gender']),
                _buildDetailRow('Phone', _patientData['phone']),
                _buildDetailRow('OP #', _patientData['opNumber']),
              ],
            ),
            const SizedBox(height: 20),

            // Medical Information Section
            _buildSection(
              title: 'Medical Information',
              children: [
                _buildDetailRow('Therapy Drug', _patientData['therapyDrug']),
                _buildDetailRow(
                  'Therapy Start Date',
                  _patientData['therapyStartDate'],
                ),
                _buildDetailRow('Target INR', _patientData['targetINR']),
                _buildDetailRow(
                  'Next Review Date',
                  _patientData['nextReviewDate'],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Doctor Information Section
            _buildSection(
              title: 'Doctor Information',
              children: [
                _buildDetailRow('Doctor', _patientData['doctor']['name']),
                _buildDetailRow('Specialty', _patientData['doctor']['specialty']),
                _buildDetailRow('Phone', _patientData['doctor']['phone']),
                _buildDetailRow('Email', _patientData['doctor']['email']),
              ],
            ),
            const SizedBox(height: 32),

            // Logout Button
            ElevatedButton.icon(
              onPressed: () => _showLogoutConfirmation(),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to login page
              Navigator.of(context).pushReplacementNamed('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
