import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/index.dart';

class PatientRecordsPage extends StatefulWidget {
  const PatientRecordsPage({super.key});

  @override
  State<PatientRecordsPage> createState() => _PatientRecordsPageState();
}

class _PatientRecordsPageState extends State<PatientRecordsPage> {
  int _currentNavIndex = 2;
  int _selectedTabIndex = 0;

  // Mock INR history data
  final List<Map<String, dynamic>> _inrHistory = [
    {
      'id': '1',
      'date': DateTime.now().subtract(const Duration(days: 5)),
      'value': 2.5,
      'targetMin': 2.0,
      'targetMax': 3.0,
      'isCritical': false,
      'notes': 'Normal range, medication working well',
    },
    {
      'id': '2',
      'date': DateTime.now().subtract(const Duration(days: 12)),
      'value': 3.2,
      'targetMin': 2.0,
      'targetMax': 3.0,
      'isCritical': false,
      'notes': 'Slightly above target, reduce dosage slightly',
    },
    {
      'id': '3',
      'date': DateTime.now().subtract(const Duration(days: 19)),
      'value': 1.8,
      'targetMin': 2.0,
      'targetMax': 3.0,
      'isCritical': false,
      'notes': 'Slightly below target, monitor closely',
    },
    {
      'id': '4',
      'date': DateTime.now().subtract(const Duration(days: 26)),
      'value': 3.5,
      'targetMin': 2.0,
      'targetMax': 3.0,
      'isCritical': true,
      'notes': 'CRITICAL: INR above safe range, urgent action needed',
    },
  ];

  // Mock health logs data
  final List<Map<String, dynamic>> _healthLogs = [
    {
      'id': '1',
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'type': 'SIDE_EFFECT',
      'description': 'Mild bruising on arm',
      'severity': 'Normal',
      'isResolved': true,
    },
    {
      'id': '2',
      'date': DateTime.now().subtract(const Duration(days: 5)),
      'type': 'ILLNESS',
      'description': 'Common cold symptoms',
      'severity': 'Normal',
      'isResolved': true,
    },
    {
      'id': '3',
      'date': DateTime.now().subtract(const Duration(days: 8)),
      'type': 'OTHER_MEDS',
      'description': 'Started taking antibiotics for infection',
      'severity': 'High',
      'isResolved': false,
    },
    {
      'id': '4',
      'date': DateTime.now().subtract(const Duration(days: 15)),
      'type': 'LIFESTYLE',
      'description': 'Increased physical activity',
      'severity': 'Normal',
      'isResolved': true,
    },
  ];

  // Mock dosage schedule
  final Map<String, double> _weeklyDosage = {
    'monday': 5.0,
    'tuesday': 5.0,
    'wednesday': 2.5,
    'thursday': 5.0,
    'friday': 5.0,
    'saturday': 2.5,
    'sunday': 5.0,
  };

  @override
  Widget build(BuildContext context) {
    return PatientScaffold(
      pageTitle: 'My Records',
      currentNavIndex: _currentNavIndex,
      onNavChanged: (index) {
        setState(() => _currentNavIndex = index);
        switch (index) {
          case 0:
            Navigator.of(context).pushReplacementNamed('/patient-home');
            break;
          case 1:
            Navigator.of(context).pushReplacementNamed('/patient-appointments');
            break;
          case 2:
            // Already on records
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
                          'INR History',
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
                          'Health Logs',
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
                          'Dosage',
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
              _buildINRHistory()
            else if (_selectedTabIndex == 1)
              _buildHealthLogs()
            else
              _buildDosageSchedule(),
          ],
        ),
      ),
    );
  }

  Widget _buildINRHistory() {
    return Column(
      children: [
        // Summary card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target INR Range',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '2.0 - 3.0',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'On Track',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // INR history list
        Text(
          'Test History',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ..._inrHistory.map((record) {
          final isWithinRange = record['value'] >= record['targetMin'] &&
              record['value'] <= record['targetMax'];

          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: record['isCritical']
                    ? Colors.red.withOpacity(0.3)
                    : isWithinRange
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(record['date']),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: record['isCritical']
                              ? Colors.red.withOpacity(0.1)
                              : isWithinRange
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'INR: ${record['value']}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: record['isCritical']
                                ? Colors.red[700]
                                : isWithinRange
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (record['notes'] != null)
                    Text(
                      record['notes'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildHealthLogs() {
    if (_healthLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.favorite, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No health logs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => _showAddHealthLogDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Health Log'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pink[400],
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 16),
        ..._healthLogs.map((log) {
          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getLogTypeLabel(log['type']),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            _formatDate(log['date']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getSeverityColor(log['severity']),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              log['severity'],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: log['isResolved']
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              log['isResolved'] ? 'Resolved' : 'Ongoing',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: log['isResolved']
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    log['description'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildDosageSchedule() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const dayKeys = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    final totalWeeklyDose = _weeklyDosage.values.fold<double>(
      0,
      (sum, dose) => sum + dose,
    );

    return Column(
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Dosage Summary',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${totalWeeklyDose.toStringAsFixed(1)} mg',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Total Weekly',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Daily Schedule',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final dose = _weeklyDosage[dayKeys[index]] ?? 0.0;
            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    days[index].substring(0, 3),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${dose.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'mg',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAddHealthLogDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Health Log'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Log Type',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: 'SIDE_EFFECT',
                items: const [
                  DropdownMenuItem(
                    value: 'SIDE_EFFECT',
                    child: Text('Side Effect'),
                  ),
                  DropdownMenuItem(
                    value: 'ILLNESS',
                    child: Text('Illness'),
                  ),
                  DropdownMenuItem(
                    value: 'LIFESTYLE',
                    child: Text('Lifestyle Change'),
                  ),
                  DropdownMenuItem(
                    value: 'OTHER_MEDS',
                    child: Text('Other Medications'),
                  ),
                ],
                onChanged: (value) {},
              ),
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Enter details...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 3,
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
                  content: Text('Health log added successfully'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getLogTypeLabel(String type) {
    const labels = {
      'SIDE_EFFECT': 'Side Effect',
      'ILLNESS': 'Illness',
      'LIFESTYLE': 'Lifestyle Change',
      'OTHER_MEDS': 'Other Medications',
    };
    return labels[type] ?? type;
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'Emergency':
        return Colors.red;
      case 'High':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
}
