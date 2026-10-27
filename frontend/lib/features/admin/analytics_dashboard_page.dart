import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/query/admin_query_keys.dart';
import 'package:frontend/core/widgets/admin/admin_access_gate.dart';
import 'package:frontend/core/widgets/admin/admin_access_scope.dart';
import 'package:frontend/core/widgets/admin/admin_scaffold.dart';
import 'package:frontend/core/widgets/common/page_skeleton.dart';
import 'package:frontend/features/admin/admin_capabilities.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';
import 'package:frontend/features/admin/models/admin_access_model.dart';
import 'package:frontend/features/admin/models/admin_stats_model.dart';

class AnalyticsDashboardPage extends StatefulWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  State<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends State<AnalyticsDashboardPage> {
  final AdminRepository _repo = AppDependencies.adminRepository;
  String _selectedPeriod = '30d';

  Future<_AnalyticsDashboardAggregate> _fetchDashboardAggregate(
    AdminAccessModel access,
  ) async {
    final canLoadDashboardStats = access.canAny(
      AdminCapabilities.dashboardRead,
    );
    final canLoadAnalytics = access.canAny(AdminCapabilities.analyticsRead);

    final statsFuture = canLoadDashboardStats
        ? _loadWithAuthStatus(_repo.getAdminStats)
        : Future.value(const _AuthLoadResult<AdminStatsModel>.skipped());
    final trendsFuture = canLoadAnalytics
        ? _loadWithAuthStatus(() => _repo.getTrends(period: _selectedPeriod))
        : Future.value(const _AuthLoadResult<RegistrationTrends>.skipped());
    final complianceFuture = canLoadAnalytics
        ? _loadWithAuthStatus(_repo.getCompliance)
        : Future.value(const _AuthLoadResult<InrComplianceStats>.skipped());
    final workloadFuture = Future.value(
      const _AuthLoadResult<DoctorWorkloadStats>.skipped(),
    );

    final stats = await statsFuture;
    final trends = await trendsFuture;
    final compliance = await complianceFuture;
    final workload = await workloadFuture;

    return _AnalyticsDashboardAggregate(
      stats: stats.value,
      statsDenied: stats.denied,
      trends: trends.value,
      trendsDenied: trends.denied,
      compliance: compliance.value,
      complianceDenied: compliance.denied,
      workload: workload.value,
      workloadDenied: workload.denied,
      loadedAt: DateTime.now(),
    );
  }

  Future<_AuthLoadResult<T>> _loadWithAuthStatus<T>(
    Future<T> Function() loader,
  ) async {
    try {
      return _AuthLoadResult.ok(await loader());
    } on ApiException catch (error) {
      // Only capability denials are swallowed as section-level empty states.
      // Network/server/validation failures rethrow so UseQuery can surface them.
      if (error.statusCode == 403 || error.kind == ApiErrorKind.forbidden) {
        return _AuthLoadResult<T>.failed(denied: true);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return AdminAccessGate(
      anyCapabilities: [
        ...AdminCapabilities.dashboardRead,
        ...AdminCapabilities.analyticsRead,
      ],
      deniedTitle: 'Analytics not available',
      deniedMessage: AppCopy.text(
        'text.your_current_administrator_policy_does_not_inclu_f685c4c9',
      ),
      builder: (context) {
        final access = AdminAccessScope.accessOf(context)!;
        final showPageScaffold = !AdminScaffold.usesShellAppBar(context);
        final periodSelector = _PeriodSelector(
          selectedPeriod: _selectedPeriod,
          onChanged: (value) => setState(() => _selectedPeriod = value),
        );

        final body = UseQuery<_AnalyticsDashboardAggregate>(
          options: QueryOptions<_AnalyticsDashboardAggregate>(
            queryKey: [
              ...AdminQueryKeys.analyticsDashboard(_selectedPeriod),
              access.role.name,
              access.policyVersion,
              ...access.effectiveCapabilities,
            ],
            queryFn: () => _fetchDashboardAggregate(access),
          ),
          builder: (context, aggregateQuery) {
            if (aggregateQuery.isLoading && aggregateQuery.data == null) {
              return const PageSkeleton(cardCount: 4);
            }

            final aggregate = aggregateQuery.data;
            if (aggregateQuery.isError && aggregate == null) {
              return _AnalyticsLoadError(
                error: aggregateQuery.error,
                onRetry: aggregateQuery.refetch,
              );
            }
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isDesktop = width > 900;
                  final isTablet = width > 600;
                  final chartHeight = isDesktop
                      ? 350.0
                      : isTablet
                      ? 330.0
                      : 300.0;

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (aggregateQuery.isError || aggregateQuery.isLoading)
                          _AnalyticsStaleBanner(
                            error: aggregateQuery.error,
                            loadedAt: aggregate?.loadedAt,
                            onRetry: aggregateQuery.refetch,
                            isRefreshing: aggregateQuery.isLoading,
                          ),
                        if (aggregateQuery.isError || aggregateQuery.isLoading)
                          const SizedBox(height: 16),
                        if (!showPageScaffold)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: isTablet
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          AppCopy.text(
                                            'text.analytics_dashboard_1fbbb8d7',
                                          ),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                      ),
                                      periodSelector,
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppCopy.text(
                                          'text.analytics_dashboard_1fbbb8d7',
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: periodSelector,
                                      ),
                                    ],
                                  ),
                          ),
                        _SummaryCards(
                          stats: aggregate?.stats,
                          denied: aggregate?.statsDenied ?? false,
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: isDesktop ? (width - 16) / 2 : width,
                              height: chartHeight,
                              child: _TrendsChart(
                                trends: aggregate?.trends,
                                denied: aggregate?.trendsDenied ?? false,
                              ),
                            ),
                            SizedBox(
                              width: isDesktop ? (width - 16) / 2 : width,
                              height: chartHeight,
                              child: _ComplianceChart(
                                compliance: aggregate?.compliance,
                                denied: aggregate?.complianceDenied ?? false,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );

        if (!showPageScaffold) {
          return body;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(AppCopy.text('text.analytics_dashboard_1fbbb8d7')),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _PeriodSelector(
                  selectedPeriod: _selectedPeriod,
                  onChanged: (value) => setState(() => _selectedPeriod = value),
                ),
              ),
            ],
          ),
          body: body,
        );
      },
    );
  }
}

class _AuthLoadResult<T> {
  const _AuthLoadResult._({this.value, this.denied = false});

  const _AuthLoadResult.ok(T value) : this._(value: value);
  const _AuthLoadResult.failed({required bool denied}) : this._(denied: denied);
  const _AuthLoadResult.skipped() : this._(denied: true);

  final T? value;
  final bool denied;
}

class _AnalyticsDashboardAggregate {
  const _AnalyticsDashboardAggregate({
    required this.stats,
    required this.statsDenied,
    required this.trends,
    required this.trendsDenied,
    required this.compliance,
    required this.complianceDenied,
    required this.workload,
    required this.workloadDenied,
    required this.loadedAt,
  });

  final AdminStatsModel? stats;
  final bool statsDenied;
  final RegistrationTrends? trends;
  final bool trendsDenied;
  final InrComplianceStats? compliance;
  final bool complianceDenied;
  final DoctorWorkloadStats? workload;
  final bool workloadDenied;
  final DateTime loadedAt;
}

class _AnalyticsLoadError extends StatelessWidget {
  const _AnalyticsLoadError({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Analytics could not be loaded.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppCopy.text('text.try_again_213e90fa')),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsStaleBanner extends StatelessWidget {
  const _AnalyticsStaleBanner({
    required this.error,
    required this.loadedAt,
    required this.onRetry,
    this.isRefreshing = false,
  });

  final Object? error;
  final DateTime? loadedAt;
  final Future<void> Function() onRetry;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final material = MaterialLocalizations.of(context);
    final timestamp = loadedAt == null
        ? 'Previously loaded data is shown.'
        : 'Showing data from ${material.formatShortDate(loadedAt!.toLocal())} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(loadedAt!.toLocal()))}.';
    final failure = isRefreshing
        ? 'Refreshing analytics.'
        : error is ApiException
        ? (error as ApiException).message
        : 'The latest refresh failed.';
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: Text('$timestamp $failure')),
            if (!isRefreshing)
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppCopy.text('text.retry_8036af59')),
              ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onChanged,
  });

  final String selectedPeriod;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return DropdownButton<String>(
      value: selectedPeriod,
      underline: const SizedBox(),
      isDense: true,
      icon: const Icon(Icons.calendar_today_rounded, size: 20),
      items: [
        DropdownMenuItem(
          value: '7d',
          child: Text(AppCopy.text('text.7_days_3a1f3659')),
        ),
        DropdownMenuItem(
          value: '30d',
          child: Text(AppCopy.text('text.30_days_fa2aded9')),
        ),
        DropdownMenuItem(
          value: '90d',
          child: Text(AppCopy.text('text.90_days_adb6e437')),
        ),
        DropdownMenuItem(
          value: '1y',
          child: Text(AppCopy.text('text.1_year_ccdcb985')),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

// ─── Summary Cards ───
class _SummaryCards extends StatelessWidget {
  final AdminStatsModel? stats;
  final bool denied;
  const _SummaryCards({this.stats, this.denied = false});

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    if (denied && stats == null) {
      return _DeniedPanel(
        title: AppCopy.text('text.dashboard_aggregates_unavailable_7f4ffde3'),
        message: AppCopy.text(
          'text.your_policy_does_not_include_dashboard_aggregate_93f8aa94',
        ),
      );
    }
    final s = stats;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _SummaryCard(
            title: AppCopy.text('text.total_patients_170282a9'),
            value: s?.patientStats.total.toString() ?? '--',
            icon: Icons.people_rounded,
            color: Colors.blue,
          ),
          _SummaryCard(
            title: AppCopy.text('text.critical_inr_7392a67f'),
            value: s?.patientStats.criticalInr?.toString() ?? '--',
            icon: Icons.warning_rounded,
            color: Colors.red,
          ),
          _SummaryCard(
            title: AppCopy.text('text.active_doctors_2dd5bbbb'),
            value: s?.doctorStats.active.toString() ?? '--',
            icon: Icons.medical_services_rounded,
            color: Colors.green,
          ),
        ];
        final isNarrow = constraints.maxWidth < 720;

        if (isNarrow) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                SizedBox(width: double.infinity, child: cards[i]),
                if (i != cards.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }
}

class _DeniedPanel extends StatelessWidget {
  const _DeniedPanel({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    AppProperties.watch(context);
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
    AppProperties.watch(context);
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
  final bool denied;
  const _TrendsChart({this.trends, this.denied = false});

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    if (denied && trends == null) {
      return _ChartCard(
        title: AppCopy.text('text.registration_trends_ead2ade4'),
        child: Center(
          child: Text(
            AppCopy.text(
              'text.access_denied_for_this_analytics_capability_92bf0fab',
            ),
          ),
        ),
      );
    }
    final data = trends?.dataPoints ?? [];
    if (data.isEmpty) {
      return _ChartCard(
        title: AppCopy.text('text.registration_trends_ead2ade4'),
        child: Center(
          child: Text(AppCopy.text('text.no_data_available_fde1f819')),
        ),
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
      title: AppCopy.text('text.registration_trends_ead2ade4'),
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
                interval: data.length > 7
                    ? (data.length / 7).ceilToDouble()
                    : 1,
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
  final bool denied;
  const _ComplianceChart({this.compliance, this.denied = false});

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    if (denied && compliance == null) {
      return _ChartCard(
        title: AppCopy.text('text.inr_compliance_8acc45e7'),
        child: Center(
          child: Text(
            AppCopy.text(
              'text.access_denied_for_this_analytics_capability_92bf0fab',
            ),
          ),
        ),
      );
    }
    final c = compliance;
    if (c == null || c.total == 0) {
      return _ChartCard(
        title: AppCopy.text('text.inr_compliance_8acc45e7'),
        child: Center(
          child: Text(AppCopy.text('text.no_data_available_fde1f819')),
        ),
      );
    }

    final items = [
      _ComplianceLegendItem(
        label: AppCopy.text('text.in_range_a08d6c07'),
        color: Colors.green,
        percentage: c.inRangePercentage,
      ),
      _ComplianceLegendItem(
        label: AppCopy.text('text.out_of_range_b913d075'),
        color: Colors.orange,
        percentage: c.outOfRangePercentage,
      ),
      _ComplianceLegendItem(
        label: AppCopy.text('text.no_data_fd6263ee'),
        color: Colors.blueGrey,
        percentage: c.noDataPercentage,
      ),
    ].where((item) => item.percentage > 0).toList();

    return _ChartCard(
      title: AppCopy.text('text.inr_compliance_8acc45e7'),
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: items
                    .map(
                      (item) => PieChartSectionData(
                        color: item.color,
                        value: item.percentage,
                        title:
                            "${(item.percentage.toStringAsFixed(0)).toString()}%",
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items
                .map(
                  (item) => _LegendChip(
                    color: item.color,
                    label:
                        "${(item.label).toString()} (${(item.percentage.toStringAsFixed(0)).toString()}%)",
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ComplianceLegendItem {
  const _ComplianceLegendItem({
    required this.label,
    required this.color,
    required this.percentage,
  });

  final String label;
  final Color color;
  final double percentage;
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
