import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/index.dart';

class PatientTakeDosagePage extends StatefulWidget {
  const PatientTakeDosagePage({super.key});

  @override
  State<PatientTakeDosagePage> createState() => _PatientTakeDosagePageState();
}

class _PatientTakeDosagePageState extends State<PatientTakeDosagePage> {
  int _currentNavIndex = 2;

  // Mock dosage data
  final List<Map<String, dynamic>> _missedDoses = [
    {
      'id': '1',
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'dose': 5.0,
      'reason': 'Forgot to take',
      'status': 'Missed',
      'markedOn': null,
    },
    {
      'id': '2',
      'date': DateTime.now().subtract(const Duration(days: 5)),
      'dose': 2.5,
      'reason': 'Out of medication',
      'status': 'Missed',
      'markedOn': null,
    },
    {
      'id': '3',
      'date': DateTime.now().subtract(const Duration(days: 8)),
      'dose': 5.0,
      'reason': 'Took late (after 12 hours)',
      'status': 'Missed',
      'markedOn': null,
    },
  ];

  final List<Map<String, dynamic>> _remainingDoses = [
    {
      'id': '1',
      'date': DateTime.now(),
      'dose': 5.0,
      'scheduledTime': '08:00 AM',
      'status': 'Pending',
      'taken': false,
    },
    {
      'id': '2',
      'date': DateTime.now().add(const Duration(days: 1)),
      'dose': 5.0,
      'scheduledTime': '08:00 AM',
      'status': 'Upcoming',
      'taken': false,
    },
    {
      'id': '3',
      'date': DateTime.now().add(const Duration(days: 2)),
      'dose': 2.5,
      'scheduledTime': '08:00 AM',
      'status': 'Upcoming',
      'taken': false,
    },
    {
      'id': '4',
      'date': DateTime.now().add(const Duration(days: 3)),
      'dose': 5.0,
      'scheduledTime': '08:00 AM',
      'status': 'Upcoming',
      'taken': false,
    },
  ];

  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return PatientScaffold(
      pageTitle: 'Dosage Management',
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
            // Already on dosage page
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
                          'Upcoming (${_remainingDoses.length})',
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
                          'Missed (${_missedDoses.length})',
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
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Content based on selected tab
            if (_selectedTabIndex == 0)
              _buildUpcomingDoses()
            else
              _buildMissedDoses(),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingDoses() {
    if (_remainingDoses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.check_circle, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No upcoming doses',
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
      children: _remainingDoses.asMap().entries.map((entry) {
        final dose = entry.value;
        final isToday = _isToday(dose['date']);

        return _DosageCard(
          dose: dose,
          isToday: isToday,
          onMarkAsTaken: () => _markDoseAsTaken(entry.key),
          onSnooze: () => _snoozeDose(entry.key),
        );
      }).toList(),
    );
  }

  Widget _buildMissedDoses() {
    if (_missedDoses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.task_alt, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No missed doses',
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
      children: _missedDoses.asMap().entries.map((entry) {
        final dose = entry.value;
        return _MissedDoseCard(
          dose: dose,
          onMarkRecovered: () => _markMissedDoseRecovered(entry.key),
        );
      }).toList(),
    );
  }

  void _markDoseAsTaken(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Dose as Taken'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm taking dosage:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              'Date:',
              _formatDate(_remainingDoses[index]['date']),
            ),
            _DetailRow('Dose:', '${_remainingDoses[index]['dose']} mg'),
            _DetailRow('Time:', _remainingDoses[index]['scheduledTime']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _remainingDoses[index]['taken'] = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dose marked as taken'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _snoozeDose(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Snooze Reminder'),
        content: const Text(
          'You will be reminded again in 1 hour.',
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
                  content: Text('Reminder snoozed for 1 hour'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Snooze'),
          ),
        ],
      ),
    );
  }

  void _markMissedDoseRecovered(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Missed Dose'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reason for missing this dose:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              _missedDoses[index]['reason'],
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add any additional notes...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
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
                  content: Text('Missed dose reported to your doctor'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _DosageCard extends StatelessWidget {
  final Map<String, dynamic> dose;
  final bool isToday;
  final VoidCallback onMarkAsTaken;
  final VoidCallback onSnooze;

  const _DosageCard({
    required this.dose,
    required this.isToday,
    required this.onMarkAsTaken,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isToday ? Colors.pink.withOpacity(0.3) : Colors.grey.shade200,
          width: isToday ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with dose amount and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dose['dose']} mg',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      dose['status'],
                      style: TextStyle(
                        fontSize: 12,
                        color: dose['status'] == 'Pending'
                            ? Colors.orange[600]
                            : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isToday ? Colors.pink.withOpacity(0.1) : null,
                    border: isToday
                        ? Border.all(color: Colors.pink)
                        : Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isToday ? 'TODAY' : 'UPCOMING',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isToday ? Colors.pink[600] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 12),

            // Date and time
            Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _formatDate(dose['date']),
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const Spacer(),
                Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  dose['scheduledTime'],
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onMarkAsTaken,
                    icon: const Icon(Icons.check),
                    label: const Text('Mark as Taken'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSnooze,
                    icon: const Icon(Icons.schedule),
                    label: const Text('Snooze'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _MissedDoseCard extends StatelessWidget {
  final Map<String, dynamic> dose;
  final VoidCallback onMarkRecovered;

  const _MissedDoseCard({
    required this.dose,
    required this.onMarkRecovered,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.red.withOpacity(0.02),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with dose amount and warning
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dose['dose']} mg',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'MISSED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                Icon(Icons.warning_rounded, color: Colors.red[400], size: 24),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.red.withOpacity(0.3)),
            const SizedBox(height: 12),

            // Date and reason
            Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _formatDate(dose['date']),
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reason',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dose['reason'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Report button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onMarkRecovered,
                icon: const Icon(Icons.report_problem),
                label: const Text('Report to Doctor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
