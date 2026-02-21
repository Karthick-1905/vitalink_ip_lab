import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/index.dart';
import 'package:frontend/app/routers.dart';
import 'package:frontend/services/patient_service.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';

class PatientRecordsPage extends StatefulWidget {
  const PatientRecordsPage({super.key});

  @override
  State<PatientRecordsPage> createState() => _PatientRecordsPageState();
}

class _PatientRecordsPageState extends State<PatientRecordsPage> {
  final int _currentNavIndex = 3;
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return UseQuery<Map<String, dynamic>>(
      options: QueryOptions<Map<String, dynamic>>(
        queryKey: const ['patient', 'records_full'],
        queryFn: () async {
          final profile = await PatientService.getProfile();
          final history = await PatientService.getINRHistory();
          return {
            'profile': profile,
            'history': history,
          };
        },
      ),
      builder: (context, query) {
        if (query.isLoading) {
          return const PatientScaffold(
            pageTitle: 'My Records',
            currentNavIndex: 3,
            onNavChanged: _dummyOnNavChanged,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (query.isError) {
          return PatientScaffold(
            pageTitle: 'My Records',
            currentNavIndex: 3,
            onNavChanged: (index) => _handleNav(index),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${query.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () => query.refetch(), child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        if (!query.hasData) {
          return const PatientScaffold(
            pageTitle: 'My Records',
            currentNavIndex: 3,
            onNavChanged: _dummyOnNavChanged,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = query.data!;
        final profile = data['profile'] as Map<String, dynamic>;
        final history = data['history'] as List<Map<String, dynamic>>;

        return PatientScaffold(
          pageTitle: 'My Records',
          currentNavIndex: _currentNavIndex,
          bodyDecoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFC8B5E1), Color(0xFFF8C7D7)],
            ),
          ),
          onNavChanged: (index) => _handleNav(index),
          body: RefreshIndicator(
            onRefresh: () async => query.refetch(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
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
                        _buildTabItem(0, 'INR History'),
                        _buildTabItem(1, 'Health Logs'),
                        _buildTabItem(2, 'Dosage'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Content based on selected tab
                  if (_selectedTabIndex == 0)
                    _buildINRHistory(profile, history)
                  else if (_selectedTabIndex == 1)
                    _buildHealthLogs(profile)
                  else
                    _buildDosageSchedule(profile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void _dummyOnNavChanged(int index) {}

  void _handleNav(int index) {
    if (index == _currentNavIndex) return;
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacementNamed(AppRoutes.patient);
        break;
      case 1:
        Navigator.of(context).pushReplacementNamed(AppRoutes.patientUpdateINR);
        break;
      case 2:
        Navigator.of(context).pushReplacementNamed(AppRoutes.patientTakeDosage);
        break;
      case 3:
        break;
      case 4:
        Navigator.of(context).pushReplacementNamed(AppRoutes.patientProfile);
        break;
    }
  }

  Widget _buildTabItem(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: isSelected
                ? Border(
                    bottom: BorderSide(
                      color: Colors.pink[400]!,
                      width: 3,
                    ),
                  )
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.pink[400] : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildINRHistory(Map<String, dynamic> profile, List<Map<String, dynamic>> history) {
    final targetINR = profile['targetINR'] ?? '2.0 - 3.0';
    
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
                      targetINR,
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
                        color: Colors.green.withValues(alpha: 0.1),
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
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No INR reports found.')),
          )
        else
          ...history.map((record) {
            final status = record['status'] as String? ?? 'Normal';
            final isCritical = status == 'High' || status == 'Low';

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isCritical
                      ? Colors.orange.withValues(alpha: 0.3)
                      : Colors.green.withValues(alpha: 0.2),
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
                          record['date'] ?? 'N/A',
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
                            color: isCritical
                                ? Colors.orange.withValues(alpha: 0.1)
                                : Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'INR: ${record['inr']}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isCritical ? Colors.orange[700] : Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (record['notes'] != null && record['notes'] != 'No notes')
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
          }),
      ],
    );
  }

  Widget _buildHealthLogs(Map<String, dynamic> profile) {
    final logs = profile['health_logs'] as List? ?? [];

    if (logs.isEmpty) {
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
        ...logs.map((log) {
          final type = log['type'] ?? 'OTHER';
          final severity = log['severity'] ?? 'Normal';
          final isResolved = log['is_resolved'] ?? true;
          final dateStr = PatientService.formatDate(log['date']);

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
                            _getLogTypeLabel(type),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            dateStr,
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
                              color: _getSeverityColor(severity),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              severity,
                              style: const TextStyle(
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
                              color: isResolved
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isResolved ? 'Resolved' : 'Ongoing',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isResolved
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
                    log['description'] ?? 'No description',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDosageSchedule(Map<String, dynamic> profile) {
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

    final weeklyDosage = profile['weeklyDosage'] as Map<String, dynamic>? ?? {};
    double totalWeeklyDose = 0;
    for (final key in dayKeys) {
      final value = weeklyDosage[key];
      if (value is num) {
        totalWeeklyDose += value.toDouble();
      } else if (value is String) {
        totalWeeklyDose += double.tryParse(value) ?? 0.0;
      }
    }

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
            final value = weeklyDosage[dayKeys[index]];
            double dose = 0.0;
            if (value is num) {
              dose = value.toDouble();
            } else if (value is String) {
              dose = double.tryParse(value) ?? 0.0;
            }
            
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
                    dose.toStringAsFixed(1),
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
