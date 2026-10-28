import 'package:frontend/core/config/app_properties.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/admin/admin_access_gate.dart';
import 'package:frontend/features/admin/admin_capabilities.dart';
import 'package:frontend/features/admin/admin_console_components.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';
import 'package:frontend/features/admin/models/admin_access_model.dart';
import 'package:frontend/features/admin/models/admin_stats_model.dart';

class PlatformHealthPage extends StatefulWidget {
  const PlatformHealthPage({super.key, this.repository});

  final AdminRepository? repository;

  @override
  State<PlatformHealthPage> createState() => _PlatformHealthPageState();
}

class _PlatformHealthPageState extends State<PlatformHealthPage> {
  late final AdminRepository _repository =
      widget.repository ?? AppDependencies.adminRepository;
  SystemHealthModel? _health;
  bool _isLoading = false;
  bool _hasLoaded = false;
  Object? _error;
  DateTime? _loadedAt;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final health = await _repository.getSystemHealth();
      if (!mounted) return;
      setState(() {
        _health = health;
        _error = null;
        _hasLoaded = true;
        _loadedAt = DateTime.now();
      });
      // Only poll while this page is the active route. IndexedStack keeps visited
      // destinations mounted, so a permanent timer would leak background traffic.
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted || !TickerMode.valuesOf(context).enabled) return;
        _load();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        // Keep hasLoaded false on first failure so the error surface is shown
        // instead of an empty/default health card.
        if (_health != null) _hasLoaded = true;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    // Cancel polling when this destination is offstage in the admin shell.
    final isActive = TickerMode.valuesOf(context).enabled;
    if (!isActive) {
      _timer?.cancel();
      _timer = null;
    } else if (_hasLoaded && _timer == null && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !TickerMode.valuesOf(context).enabled ||
            _timer != null) {
          return;
        }
        _timer = Timer.periodic(const Duration(seconds: 30), (_) {
          if (!mounted || !TickerMode.valuesOf(context).enabled) return;
          _load();
        });
      });
    }
    return AdminAccessGate(
      anyCapabilities: const [AdminCapabilities.platformSystemHealthRead],
      roles: const {AdminRole.appAdmin, AdminRole.auditor},
      scope: AdminScope.global,
      deniedMessage: AppCopy.text(
        'text.platform_health_is_available_only_to_an_applicat_bee21e2e',
      ),
      builder: (context) {
        if (!_hasLoaded && !_isLoading && _error == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _load());
        }
        final body = ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminPageHeader(
              title: AppCopy.text('text.platform_health_e5beca84'),
              subtitle: AppCopy.text(
                'text.global_service_and_dependency_status_sensitive_c_a7730e71',
              ),
              actions: [
                IconButton(
                  onPressed: _isLoading ? null : _load,
                  tooltip: AppCopy.text(
                    'text.refresh_platform_health_f017c4a7',
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading && !_hasLoaded && _error == null)
              const Center(child: CircularProgressIndicator())
            else if (_error != null && _health == null)
              _HealthLoadError(error: _error!, onRetry: _load)
            else ...[
              if (_error != null)
                _StaleHealthBanner(
                  error: _error!,
                  loadedAt: _loadedAt,
                  onRetry: _load,
                ),
              if (_error != null) const SizedBox(height: 12),
              SystemHealthSection(
                health: _health,
                healthUnavailable: _error != null,
              ),
            ],
          ],
        );
        return adminPageScaffold(context, 'Platform Health', body);
      },
    );
  }
}

class HospitalOperationsHealthPage extends StatefulWidget {
  const HospitalOperationsHealthPage({super.key, this.repository});

  final AdminRepository? repository;

  @override
  State<HospitalOperationsHealthPage> createState() =>
      _HospitalOperationsHealthPageState();
}

class _HospitalOperationsHealthPageState
    extends State<HospitalOperationsHealthPage> {
  late final AdminRepository _repository =
      widget.repository ?? AppDependencies.adminRepository;
  Map<String, dynamic>? _health;
  bool _isLoading = false;
  bool _hasLoaded = false;
  Object? _error;
  DateTime? _loadedAt;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final health = await _repository.getReminderDeliveryHealth();
      if (!mounted) return;
      setState(() {
        _health = health;
        _error = null;
        _hasLoaded = true;
        _loadedAt = DateTime.now();
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted || !TickerMode.valuesOf(context).enabled) return;
        _load();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        if (_health != null) _hasLoaded = true;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final isActive = TickerMode.valuesOf(context).enabled;
    if (!isActive) {
      _timer?.cancel();
      _timer = null;
    } else if (_hasLoaded && _timer == null && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !TickerMode.valuesOf(context).enabled ||
            _timer != null) {
          return;
        }
        _timer = Timer.periodic(const Duration(seconds: 30), (_) {
          if (!mounted || !TickerMode.valuesOf(context).enabled) return;
          _load();
        });
      });
    }
    return AdminAccessGate(
      anyCapabilities: const [AdminCapabilities.tenantOperationsHealthRead],
      roles: const {AdminRole.hospitalAdmin},
      scope: AdminScope.tenant,
      deniedMessage: AppCopy.text(
        'text.hospital_operations_health_is_available_only_to__5efe1aa2',
      ),
      builder: (context) {
        if (!_hasLoaded && !_isLoading && _error == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _load());
        }
        final data = _health ?? const <String, dynamic>{};
        final statuses = data['deliveriesByStatus'] is Map
            ? Map<String, dynamic>.from(data['deliveriesByStatus'] as Map)
            : const <String, dynamic>{};
        final body = ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminPageHeader(
              title: AppCopy.text('text.hospital_operations_health_91501a3'),
              subtitle: AppCopy.text(
                'text.reminder_and_delivery_status_for_your_assigned_h_3076af9c',
              ),
              actions: [
                IconButton(
                  onPressed: _isLoading ? null : _load,
                  tooltip: AppCopy.text(
                    'text.refresh_hospital_operations_health_30c18ad6',
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading && !_hasLoaded && _error == null)
              const Center(child: CircularProgressIndicator())
            else if (_error != null && _health == null)
              _HealthLoadError(error: _error!, onRetry: _load)
            else ...[
              if (_error != null)
                _StaleHealthBanner(
                  error: _error!,
                  loadedAt: _loadedAt,
                  onRetry: _load,
                ),
              if (_error != null) const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _HealthMetric(
                        'Reminders (24h)',
                        '${data['remindersLast24Hours'] ?? 0}',
                        Icons.notifications_active_outlined,
                        Theme.of(context).colorScheme.primary,
                      ),
                      _HealthMetric(
                        'Delivered',
                        '${statuses['SUCCEEDED'] ?? 0}',
                        Icons.check_circle_outline,
                        Colors.green,
                      ),
                      _HealthMetric(
                        'Needs attention',
                        '${data['overdueDeliveries'] ?? 0}',
                        Icons.warning_amber_rounded,
                        Theme.of(context).colorScheme.error,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
        return adminPageScaffold(context, 'Hospital Operations Health', body);
      },
    );
  }
}

class _StaleHealthBanner extends StatelessWidget {
  const _StaleHealthBanner({
    required this.error,
    required this.loadedAt,
    required this.onRetry,
  });

  final Object error;
  final DateTime? loadedAt;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final timestamp = loadedAt == null
        ? 'Previously loaded health data is shown.'
        : 'Showing data loaded ${MaterialLocalizations.of(context).formatFullDate(loadedAt!.toLocal())} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(loadedAt!.toLocal()))}.';
    final message = error is ApiException
        ? (error as ApiException).message
        : 'The latest refresh failed.';
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: Text('$timestamp $message')),
            TextButton(
              onPressed: onRetry,
              child: Text(AppCopy.text('text.retry_8036af59')),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthLoadError extends StatelessWidget {
  const _HealthLoadError({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Hospital operations health could not be loaded.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
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

class SystemHealthSection extends StatelessWidget {
  const SystemHealthSection({
    super.key,
    required this.health,
    required this.healthUnavailable,
  });

  final SystemHealthModel? health;
  final bool healthUnavailable;

  String _formatUptime(double seconds) {
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    if (hours > 24) {
      final days = (hours / 24).floor();
      return AppCopy.text(
        'text.value1_d_value2_h_34ce93de',
        arguments: {
          'value1': (days).toString(),
          'value2': (hours % 24).toString(),
        },
      );
    }
    return AppCopy.text(
      'text.value1_h_value2_m_4796d319',
      arguments: {'value1': (hours).toString(), 'value2': (minutes).toString()},
    );
  }

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final theme = Theme.of(context);
    final h = health;
    final isHealthy = h?.status == 'healthy';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.monitor_heart, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      AppCopy.text('text.system_health_b2e050a2'),
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
                Chip(
                  label: Text(
                    h != null
                        ? (isHealthy
                              ? AppCopy.text('text.healthy_b720efe2')
                              : AppCopy.text('text.issues_c0837669'))
                        : (healthUnavailable
                              ? AppCopy.text('text.unavailable_da4baaa9')
                              : AppCopy.text('text.loading_17b11033')),
                  ),
                  backgroundColor: h == null
                      ? Colors.grey.withValues(alpha: 0.1)
                      : (isHealthy
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (h != null)
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _HealthMetric(
                    'Database',
                    h.database.status.toUpperCase(),
                    Icons.check_circle,
                    isHealthy ? Colors.green : Colors.red,
                  ),
                  _HealthMetric(
                    'Uptime',
                    _formatUptime(h.uptime),
                    Icons.access_time,
                    Colors.blue,
                  ),
                ],
              )
            else if (healthUnavailable)
              Text(
                AppCopy.text(
                  'text.system_health_is_unavailable_or_restricted_for_t_29067b32',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HealthMetric extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _HealthMetric(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
