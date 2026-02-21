import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:frontend/core/widgets/index.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/app/routers.dart';
import 'package:frontend/services/patient_service.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:intl/intl.dart';

class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key});

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  final int _currentNavIndex = 4;

  @override
  Widget build(BuildContext context) {
    return UseQuery<Map<String, dynamic>>(
      options: QueryOptions<Map<String, dynamic>>(
        queryKey: const ['patient', 'profile_full'],
        queryFn: () async {
          final profile = await PatientService.getProfile();
          final history = await PatientService.getINRHistory();
          final latest = await PatientService.getLatestINR();
          return {
            'profile': profile,
            'history': history,
            'latest': latest,
          };
        },
      ),
      builder: (context, query) {
        if (query.isLoading) {
          return const PatientScaffold(
            pageTitle: '@ Profile Page',
            currentNavIndex: 0,
            onNavChanged: _dummyOnNavChanged,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (query.isError) {
          return PatientScaffold(
            pageTitle: '@ Profile Page',
            currentNavIndex: 0,
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
            pageTitle: '@ Profile Page',
            currentNavIndex: 0,
            onNavChanged: _dummyOnNavChanged,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = query.data!;
        final profile = data['profile'] as Map<String, dynamic>;
        final history = data['history'] as List<Map<String, dynamic>>;
        final latestINR = data['latest'] as double;

        return PatientScaffold(
          pageTitle: 'My Profile',
          currentNavIndex: _currentNavIndex,
          onNavChanged: (index) => _handleNav(index),
          bodyDecoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
          ),
          body: RefreshIndicator(
            onRefresh: () async => query.refetch(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Section (Avatar, Name, Info Cards, Details, Actions)
                  PatientProfileContent(
                    profile: profile,
                    onProfileUpdated: () => query.refetch(),
                  ),
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
      case 0: Navigator.of(context).pushReplacementNamed(AppRoutes.patient); break;
      case 1: Navigator.of(context).pushReplacementNamed(AppRoutes.patientUpdateINR); break;
      case 2: Navigator.of(context).pushReplacementNamed(AppRoutes.patientTakeDosage); break;
      case 3: Navigator.of(context).pushReplacementNamed(AppRoutes.patientHealthReports); break;
      case 4: break;
    }
  }

  Widget _buildPremiumSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9CA3AF),
              letterSpacing: 1,
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildMedicalHistoryList(Map<String, dynamic> profile) {
    final history = profile['medicalHistory'] as List? ?? [];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: history.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No medical history found', style: TextStyle(color: Colors.black45)),
              ),
            )
          : Column(
              children: history.map((h) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.history, color: Color(0xFFEF4444), size: 16),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h['diagnosis'] ?? 'Condition',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87),
                            ),
                            Text(
                              'Since ${h['duration_value']} ${h['duration_unit']}',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildINRChart(List<Map<String, dynamic>> inrHistory) {
    if (inrHistory.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('Insufficient data for trend', style: TextStyle(color: Colors.black45))),
      );
    }

    final spots = inrHistory.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['inr'])).toList();

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 24, 24, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.1),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (val, meta) {
                  if (val.toInt() >= 0 && val.toInt() < inrHistory.length) {
                    final date = inrHistory[val.toInt()]['date'] as String;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        date.split('-')[0], // Day
                        style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                getTitlesWidget: (val, meta) => Text(
                  val.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10, color: Colors.black45),
                ),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF6366F1),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 3,
                  strokeColor: const Color(0xFF6366F1),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.2),
                    const Color(0xFF6366F1).withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionTable(Map<String, dynamic> profile) {
    final dosage = profile['weeklyDosage'] as Map? ?? {};
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(1),
          },
          border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
              children: [
                _tableHeader('DAY'),
                _tableHeader('DOSE (MG)'),
              ],
            ),
            ...days.map((d) => TableRow(
                  children: [
                    _tableCell(d.toUpperCase().substring(0, 3)),
                    _tableCell('${dosage[d] ?? 0}', isBold: true),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.5),
      ),
    );
  }

  Widget _tableCell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: isBold ? Colors.black87 : Colors.black54,
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => LogoutDialog(
        onLogout: () async {
          final SecureStorage secureStorage = AppDependencies.secureStorage;
          await secureStorage.clearAll();
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.login,
              (route) => false,
            );
          }
        },
      ),
    );
  }
}
