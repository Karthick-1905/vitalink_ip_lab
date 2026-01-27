import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/index.dart';

class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key});

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  int _currentNavIndex = 3;
  int _selectedTabIndex = 0;

  // Mock patient data
  final Map<String, dynamic> _patientData = {
    'demographics': {
      'name': 'John Doe',
      'age': 45,
      'gender': 'Male',
      'phone': '+91-98765-43210',
      'nextOfKin': {
        'name': 'Jane Doe',
        'relation': 'Spouse',
        'phone': '+91-98765-43211',
      },
    },
    'medicalConfig': {
      'therapyDrug': 'Warfarin',
      'therapyStartDate': DateTime(2023, 6, 15),
      'targetInr': {
        'min': 2.0,
        'max': 3.0,
      },
      'nextReviewDate': DateTime.now().add(const Duration(days: 10)),
      'instructions': [
        'Take medication at the same time every day',
        'Avoid sudden dietary changes, especially vitamin K',
        'Report any unusual bleeding or bruising immediately',
        'Regular INR testing every 2-4 weeks',
        'Inform all healthcare providers about anticoagulation therapy',
      ],
    },
    'medicalHistory': [
      {
        'diagnosis': 'Atrial Fibrillation',
        'duration': '3 years',
      },
      {
        'diagnosis': 'Hypertension',
        'duration': '8 years',
      },
      {
        'diagnosis': 'Type 2 Diabetes',
        'duration': '5 years',
      },
    ],
    'assignedDoctor': {
      'name': 'Dr. Rajesh Kumar',
      'specialty': 'Cardiology',
      'phone': '+91-98765-54321',
      'email': 'rajesh.kumar@hospital.com',
    },
  };

  @override
  Widget build(BuildContext context) {
    return PatientScaffold(
      pageTitle: 'My Profile',
      currentNavIndex: _currentNavIndex,
      onNavChanged: (index) {
        setState(() => _currentNavIndex = index);
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
            // Tabs
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: _selectedTabIndex == 0
                              ? Border(
                                  bottom: BorderSide(
                                    color: Colors.pink[400]!,
                                    width: 3,
                                  ),
                                )
                              : null,
                        ),
                        child: Text(
                          'Personal Info',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _selectedTabIndex == 0
                                ? Colors.pink[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: _selectedTabIndex == 1
                              ? Border(
                                  bottom: BorderSide(
                                    color: Colors.pink[400]!,
                                    width: 3,
                                  ),
                                )
                              : null,
                        ),
                        child: Text(
                          'Medical Info',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _selectedTabIndex == 1
                                ? Colors.pink[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: _selectedTabIndex == 2
                              ? Border(
                                  bottom: BorderSide(
                                    color: Colors.pink[400]!,
                                    width: 3,
                                  ),
                                )
                              : null,
                        ),
                        child: Text(
                          'Doctor',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _selectedTabIndex == 2
                                ? Colors.pink[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Content based on selected tab
            if (_selectedTabIndex == 0)
              _buildPersonalInfo()
            else if (_selectedTabIndex == 1)
              _buildMedicalInfo()
            else
              _buildDoctorInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfo() {
    final demographics = _patientData['demographics'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Avatar and name section
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.pink[100],
                child: Text(
                  demographics['name']
                      .split(' ')
                      .map((word) => word[0])
                      .join()
                      .toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.pink,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                demographics['name'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Patient • Active',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Personal details
        _buildInfoSection(
          title: 'Personal Details',
          children: [
            _buildInfoRow('Age', '${demographics['age']} years'),
            _buildInfoRow('Gender', demographics['gender']),
            _buildInfoRow('Phone', demographics['phone']),
          ],
        ),
        const SizedBox(height: 20),

        // Next of kin
        _buildInfoSection(
          title: 'Next of Kin',
          children: [
            _buildInfoRow('Name', demographics['nextOfKin']['name']),
            _buildInfoRow('Relation', demographics['nextOfKin']['relation']),
            _buildInfoRow('Phone', demographics['nextOfKin']['phone']),
          ],
        ),
        const SizedBox(height: 20),

        // Edit profile button
        ElevatedButton(
          onPressed: () => _showEditProfileDialog(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pink[400],
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text(
            'Edit Profile',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicalInfo() {
    final medicalConfig = _patientData['medicalConfig'];
    final medicalHistory = _patientData['medicalHistory'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Therapy information
        _buildInfoSection(
          title: 'Anticoagulation Therapy',
          children: [
            _buildInfoRow('Drug', medicalConfig['therapyDrug']),
            _buildInfoRow(
              'Started',
              _formatDate(medicalConfig['therapyStartDate']),
            ),
            _buildInfoRow(
              'Target INR Range',
              '${medicalConfig['targetInr']['min']} - ${medicalConfig['targetInr']['max']}',
            ),
            _buildInfoRow(
              'Next Review',
              _formatDate(medicalConfig['nextReviewDate']),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Medical history
        _buildInfoSection(
          title: 'Medical History',
          children: medicalHistory
              .map<Widget>((history) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                history['diagnosis'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                history['duration'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),

        // Instructions
        Card(
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
                  'Important Instructions',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                ...(medicalConfig['instructions'] as List<String>)
                    .map((instruction) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.pink,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  instruction,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorInfo() {
    final doctor = _patientData['assignedDoctor'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Doctor card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: Text(
                    doctor['name']
                        .split(' ')
                        .map((word) => word[0])
                        .join()
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  doctor['name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    doctor['specialty'],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Contact information
        _buildInfoSection(
          title: 'Contact Information',
          children: [
            _buildInfoRow('Phone', doctor['phone']),
            _buildInfoRow('Email', doctor['email']),
          ],
        ),
        const SizedBox(height: 20),

        // Action buttons
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Calling doctor...'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.phone),
          label: const Text('Call Doctor'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening email client...'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.email),
          label: const Text('Send Email'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 20),

        // Messages section
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(Icons.message, color: Colors.blue[600]),
            title: const Text('Send Message to Doctor'),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Messaging feature coming soon'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection({
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
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Phone Number',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(
                  text: _patientData['demographics']['phone'],
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Next of Kin Phone',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(
                  text: _patientData['demographics']['nextOfKin']['phone'],
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
