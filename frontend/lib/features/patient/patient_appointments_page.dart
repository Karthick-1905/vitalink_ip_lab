import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/index.dart';

class PatientAppointmentsPage extends StatefulWidget {
  const PatientAppointmentsPage({super.key});

  @override
  State<PatientAppointmentsPage> createState() =>
      _PatientAppointmentsPageState();
}

class _PatientAppointmentsPageState extends State<PatientAppointmentsPage> {
  int _currentNavIndex = 1;
  int _selectedTabIndex = 0;

  // Mock appointments data
  final List<Map<String, dynamic>> _upcomingAppointments = [
    {
      'id': '1',
      'doctorName': 'Dr. Rajesh Kumar',
      'specialty': 'Cardiology',
      'date': DateTime.now().add(const Duration(days: 5)),
      'time': '10:30 AM',
      'location': 'Room 204, Building A',
      'status': 'Confirmed',
    },
    {
      'id': '2',
      'doctorName': 'Dr. Priya Sharma',
      'specialty': 'Internal Medicine',
      'date': DateTime.now().add(const Duration(days: 12)),
      'time': '2:00 PM',
      'location': 'Room 105, Building B',
      'status': 'Confirmed',
    },
    {
      'id': '3',
      'doctorName': 'Dr. Anjali Patel',
      'specialty': 'Hematology',
      'date': DateTime.now().add(const Duration(days: 20)),
      'time': '11:00 AM',
      'location': 'Room 301, Building C',
      'status': 'Pending',
    },
  ];

  final List<Map<String, dynamic>> _pastAppointments = [
    {
      'id': '4',
      'doctorName': 'Dr. Rajesh Kumar',
      'specialty': 'Cardiology',
      'date': DateTime.now().subtract(const Duration(days: 15)),
      'time': '10:30 AM',
      'location': 'Room 204, Building A',
      'status': 'Completed',
      'notes': 'INR levels stable, continue current medication',
    },
    {
      'id': '5',
      'doctorName': 'Dr. Priya Sharma',
      'specialty': 'Internal Medicine',
      'date': DateTime.now().subtract(const Duration(days: 30)),
      'time': '2:00 PM',
      'location': 'Room 105, Building B',
      'status': 'Completed',
      'notes': 'Follow-up successful, INR within target range',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return PatientScaffold(
      pageTitle: 'My Appointments',
      currentNavIndex: _currentNavIndex,
      onNavChanged: (index) {
        setState(() => _currentNavIndex = index);
        switch (index) {
          case 0:
            Navigator.of(context).pushReplacementNamed('/patient-home');
            break;
          case 1:
            // Already on appointments
            break;
          case 2:
            Navigator.of(context).pushReplacementNamed('/patient-records');
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
                          'Upcoming (${_upcomingAppointments.length})',
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
                          'Past (${_pastAppointments.length})',
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
              _buildUpcomingAppointments()
            else
              _buildPastAppointments(),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingAppointments() {
    if (_upcomingAppointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.calendar_today, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No upcoming appointments',
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
      children: _upcomingAppointments.map((appointment) {
        return _AppointmentCard(
          appointment: appointment,
          onViewDetails: () => _showAppointmentDetails(appointment),
          onReschedule: () => _showRescheduleDialog(appointment),
          onCancel: () => _showCancelDialog(appointment),
        );
      }).toList(),
    );
  }

  Widget _buildPastAppointments() {
    if (_pastAppointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No past appointments',
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
      children: _pastAppointments.map((appointment) {
        return _PastAppointmentCard(
          appointment: appointment,
          onViewDetails: () => _showAppointmentDetails(appointment),
        );
      }).toList(),
    );
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Appointment Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Doctor:', appointment['doctorName']),
              _DetailRow('Specialty:', appointment['specialty']),
              _DetailRow(
                'Date:',
                '${_formatDate(appointment['date'])} at ${appointment['time']}',
              ),
              _DetailRow('Location:', appointment['location']),
              _DetailRow('Status:', appointment['status']),
              if (appointment['notes'] != null)
                _DetailRow('Notes:', appointment['notes']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRescheduleDialog(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reschedule Appointment'),
        content: const Text(
          'This will request a reschedule with the doctor. The doctor will confirm the new time.',
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
                  content: Text('Reschedule request sent to doctor'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Request Reschedule'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text(
          'Are you sure you want to cancel this appointment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep It'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Appointment cancelled'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Cancel Appointment'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onViewDetails;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;

  const _AppointmentCard({
    required this.appointment,
    required this.onViewDetails,
    required this.onReschedule,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final date = appointment['date'] as DateTime;
    final isToday = DateTime.now().year == date.year &&
        DateTime.now().month == date.month &&
        DateTime.now().day == date.day;

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
            // Header with doctor name and status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment['doctorName'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        appointment['specialty'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: appointment['status'] == 'Confirmed'
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    appointment['status'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: appointment['status'] == 'Confirmed'
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 12),

            // Date, time, and location
            Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  appointment['time'],
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appointment['location'],
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onViewDetails,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.pink),
                    ),
                    child: const Text(
                      'Details',
                      style: TextStyle(color: Colors.pink),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReschedule,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue),
                    ),
                    child: const Text(
                      'Reschedule',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PastAppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onViewDetails;

  const _PastAppointmentCard({
    required this.appointment,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final date = appointment['date'] as DateTime;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.grey.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with doctor name and completed badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment['doctorName'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        appointment['specialty'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
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
                    appointment['status'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 12),

            // Date and time
            Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  appointment['time'],
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
            if (appointment['notes'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Doctor Notes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointment['notes'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onViewDetails,
                child: const Text(
                  'View Full Details',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
