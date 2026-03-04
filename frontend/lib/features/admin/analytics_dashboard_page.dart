import 'package:flutter/material.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/query/admin_query_keys.dart';
import 'package:frontend/core/widgets/admin/admin_scaffold.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';
import 'package:frontend/features/admin/models/admin_stats_model.dart';

class AnalyticsDashboardPage extends StatefulWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  State<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends State<AnalyticsDashboardPage> {
  final AdminRepository _repo = AppDependencies.adminRepository;
  String _selectedPeriod = '30d';

  Future<_AnalyticsDashboardAggregate> _fetchDashboardAggregate() async {
    final statsFuture = _safeLoad(_repo.getAdminStats);
    final trendsFuture = _safeLoad(
      () => _repo.getTrends(period: _selectedPeriod),
    );
    final complianceFuture = _safeLoad(_repo.getCompliance);
    final workloadFuture = _safeLoad(_repo.getWorkload);

    final stats = await statsFuture;
    final trends = await trendsFuture;
    final compliance = await complianceFuture;
    final workload = await workloadFuture;

    return _AnalyticsDashboardAggregate(
      stats: stats,
      trends: trends,
      compliance: compliance,
      workload: workload ?? const [],
    );
  }

  Future<T?> _safeLoad<T>(Future<T> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showPageScaffold = !AdminScaffold.usesShellAppBar(context);

    final body = UseQuery<_AnalyticsDashboardAggregate>(
      options: QueryOptions<_AnalyticsDashboardAggregate>(
        queryKey: AdminQueryKeys.analyticsDashboard(_selectedPeriod),
        queryFn: _fetchDashboardAggregate,
      ),
      builder: (context, aggregateQuery) {
        if (aggregateQuery.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final aggregate = aggregateQuery.data;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!showPageScaffold)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Analytics Dashboard',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      DropdownButton<String>(
                        value: _selectedPeriod,
                        underline: const SizedBox(),
                        icon: const Icon(
                          Icons.calendar_today_rounded,
                          size: 20,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: '7d',
                            child: Text('7 Days'),
                          ),
                          DropdownMenuItem(
                            value: '30d',
                            child: Text('30 Days'),
                          ),
                          DropdownMenuItem(
                            value: '90d',
                            child: Text('90 Days'),
                          ),
                          DropdownMenuItem(
                            value: '1y',
                            child: Text('1 Year'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedPeriod = v);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              _SummaryCards(stats: aggregate?.stats),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isDesktop = width > 900;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: isDesktop ? (width - 16) / 2 : width,
                        height: 350,
                        child: _TrendsChart(trends: aggregate?.trends),
                      ),
                      SizedBox(
                        width: isDesktop ? (width - 16) / 2 : width,
                        height: 350,
                        child: _ComplianceChart(
                          compliance: aggregate?.compliance,
                        ),
                      ),
                      SizedBox(
                        width: isDesktop ? (width - 16) / 2 : width,
                        height: 350,
                        child: _WorkloadChart(
                          workload: aggregate?.workload ?? const [],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    if (!showPageScaffold) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButton<String>(
              value: _selectedPeriod,
              underline: const SizedBox(),
              icon: const Icon(Icons.calendar_today_rounded, size: 20),
              items: const [
                DropdownMenuItem(value: '7d', child: Text('7 Days')),
                DropdownMenuItem(value: '30d', child: Text('30 Days')),
                DropdownMenuItem(value: '90d', child: Text('90 Days')),
                DropdownMenuItem(value: '1y', child: Text('1 Year')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedPeriod = v);
              },
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _AnalyticsDashboardAggregate {
  const _AnalyticsDashboardAggregate({
    required this.stats,
    required this.trends,
    required this.compliance,
    required this.workload,
  });

  final AdminStatsModel? stats;
  final RegistrationTrends? trends;
  final InrComplianceStats? compliance;
  final List<DoctorWorkload> workload;
}

// ─── Summary Cards ───
class _SummaryCards extends StatelessWidget {
  final AdminStatsModel? stats;
  const _SummaryCards({this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Total Patients',
            value: s?.patientStats.total.toString() ?? '--',
            icon: Icons.people_rounded,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            title: 'Critical INR',
            value: s?.patientStats.criticalInr.toString() ?? '--',
            icon: Icons.warning_rounded,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            title: 'Active Doctors',
            value: s?.doctorStats.active.toString() ?? '--',
            icon: Icons.medical_services_rounded,
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chart Wrapper ───
class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ─── Registration Trends ───
class _TrendsChart extends StatelessWidget {
  final RegistrationTrends? trends;
  const _TrendsChart({this.trends});

  @override
  Widget build(BuildContext context) {
    final data = trends?.dataPoints ?? [];
    if (data.isEmpty) {
      return _ChartCard(
        title: 'Registration Trends',
        child: const Center(child: Text('No data available')),
      );
    }

    final patientSpots = <FlSpot>[];
    final doctorSpots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      patientSpots.add(FlSpot(i.toDouble(), data[i].patients.toDouble()));
      doctorSpots.add(FlSpot(i.toDouble(), data[i].doctors.toDouble()));
    }
    final maxP = data.fold<int>(0, (m, t) => t.patients > m ? t.patients : m);
    final maxD = data.fold<int>(0, (m, t) => t.doctors > m ? t.doctors : m);
    final maxY = ((maxP > maxD ? maxP : maxD) * 1.2).ceilToDouble();

    return _ChartCard(
      title: 'Registration Trends',
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval:
                    data.length > 7 ? (data.length / 7).ceilToDouble() : 1,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i >= 0 && i < data.length) {
                    final parts = data[i].date.split('-');
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        parts.length >= 2
                            ? '${parts[1]}/${parts.length > 2 ? parts[2] : ""}'
                            : '',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: maxY > 0 ? maxY / 4 : 1,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: maxY > 0 ? maxY : 10,
          lineBarsData: [
            LineChartBarData(
              spots: patientSpots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withValues(alpha: 0.1),
              ),
            ),
            LineChartBarData(
              spots: doctorSpots,
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── INR Compliance ───
class _ComplianceChart extends StatelessWidget {
  final InrComplianceStats? compliance;
  const _ComplianceChart({this.compliance});

  @override
  Widget build(BuildContext context) {
    final c = compliance;
    if (c == null || c.total == 0) {
      return _ChartCard(
        title: 'INR Compliance',
        child: const Center(child: Text('No data available')),
      );
    }

    return _ChartCard(
      title: 'INR Compliance',
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: [
            if (c.inRangePercentage > 0)
              PieChartSectionData(
                color: Colors.green,
                value: c.inRangePercentage,
                title: '${c.inRangePercentage.toStringAsFixed(0)}%',
                radius: 50,
                titleStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            if (c.outOfRangePercentage > 0)
              PieChartSectionData(
                color: Colors.orange,
                value: c.outOfRangePercentage,
                title: '${c.outOfRangePercentage.toStringAsFixed(0)}%',
                radius: 50,
                titleStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            if (c.criticalPercentage > 0)
              PieChartSectionData(
                color: Colors.red,
                value: c.criticalPercentage,
                title: '${c.criticalPercentage.toStringAsFixed(0)}%',
                radius: 50,
                titleStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Doctor Workload ───
class _WorkloadChart extends StatelessWidget {
  final List<DoctorWorkload> workload;
  const _WorkloadChart({required this.workload});

  @override
  Widget build(BuildContext context) {
    if (workload.isEmpty) {
      return _ChartCard(
        title: 'Doctor Workload',
        child: const Center(child: Text('No data available')),
      );
    }
    final top = workload.take(10).toList();
    final maxP = top.fold<int>(
      0,
      (m, d) => d.patientCount > m ? d.patientCount : m,
    );
    final maxY = (maxP * 1.2).ceilToDouble();

    return _ChartCard(
      title: 'Doctor Workload',
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY > 0 ? maxY : 20,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i >= 0 && i < top.length) {
                    final n = top[i].doctorName ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: Text(
                          n.length > 10 ? '${n.substring(0, 8)}..' : n,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: maxY > 0 ? maxY / 4 : 5,
              ),
            ),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: top.asMap().entries.map((e) {
            final hue = (200 + e.key * 15) % 360;
            final color = HSLColor.fromAHSL(
              1,
              hue.toDouble(),
              0.6,
              0.5,
            ).toColor();
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.patientCount.toDouble(),
                  color: color,
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
