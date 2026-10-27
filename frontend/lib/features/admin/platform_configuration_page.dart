import 'package:frontend/features/admin/presentation_properties_editor.dart';
import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/admin/admin_access_gate.dart';
import 'package:frontend/core/widgets/admin/admin_access_scope.dart';
import 'package:frontend/features/admin/admin_capabilities.dart';
import 'package:frontend/features/admin/admin_console_components.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';
import 'package:frontend/features/admin/models/admin_access_model.dart';

class PlatformConfigurationPage extends StatefulWidget {
  const PlatformConfigurationPage({super.key, this.repository});

  final AdminRepository? repository;

  @override
  State<PlatformConfigurationPage> createState() =>
      _PlatformConfigurationPageState();
}

class _PlatformConfigurationPageState extends State<PlatformConfigurationPage> {
  late final AdminRepository _repository =
      widget.repository ?? AppDependencies.adminRepository;
  final _formKey = GlobalKey<FormState>();
  final _inrLowController = TextEditingController();
  final _inrHighController = TextEditingController();
  final _sessionTimeoutController = TextEditingController();
  final _maxRequestsController = TextEditingController();
  final _windowDurationController = TextEditingController();
  Map<String, bool> _featureFlags = const {};
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _hasUnsavedChanges = false;
  Object? _error;
  DateTime? _loadedAt;

  @override
  void dispose() {
    _inrLowController.dispose();
    _inrHighController.dispose();
    _sessionTimeoutController.dispose();
    _maxRequestsController.dispose();
    _windowDurationController.dispose();
    super.dispose();
  }

  Future<void> _load({bool discardDraft = false}) async {
    if (_isLoading) return;
    if (_hasUnsavedChanges && !discardDraft) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(AppCopy.text('text.discard_unsaved_changes_8f433e17')),
          content: Text(
            AppCopy.text(
              'text.reloading_replaces_your_local_platform_configura_30c92c3b',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppCopy.text('text.keep_editing_d233d38c')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(AppCopy.text('text.discard_and_reload_fe48f2d1')),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final config = await _repository.getSystemConfig();
      final thresholds =
          config['inr_thresholds'] ?? config['medical_thresholds'] ?? const {};
      final rateLimit =
          config['rate_limiting'] ?? config['rate_limit'] ?? const {};
      if (!mounted) return;
      setState(() {
        _inrLowController.text =
            '${thresholds['critical_low'] ?? thresholds['inr_critical_low'] ?? 1.5}';
        _inrHighController.text =
            '${thresholds['critical_high'] ?? thresholds['inr_critical_high'] ?? 4.5}';
        _sessionTimeoutController.text =
            '${config['session_timeout_minutes'] ?? 30}';
        _maxRequestsController.text = '${rateLimit['max_requests'] ?? 100}';
        _windowDurationController.text = '${rateLimit['window_minutes'] ?? 15}';
        final rawFlags = config['feature_flags'];
        _featureFlags = rawFlags is Map
            ? rawFlags.map(
                (key, value) => MapEntry(key.toString(), value == true),
              )
            : {
                'maintenance_mode': false,
                'patient_registration_enabled': true,
                'notifications_enabled': true,
              };
        _hasLoaded = true;
        _loadedAt = DateTime.now();
        _hasUnsavedChanges = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        // Do not flip hasLoaded on first failure — that would render the empty
        // form defaults as if they were server state.
      });
      if (_hasLoaded && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : AppCopy.text(
                      'text.could_not_refresh_platform_configuration_7c25e52d',
                    ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppCopy.text('text.save_platform_configuration_7bd39c1e')),
        content: Text(
          AppCopy.text(
            'text.these_global_settings_take_effect_across_vitalin_95764777',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppCopy.text('text.cancel_35afca3b')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppCopy.text('text.save_configuration_d495a0fa')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await _repository.updateSystemConfig({
        'inr_thresholds': {
          'critical_low': double.parse(_inrLowController.text),
          'critical_high': double.parse(_inrHighController.text),
        },
        'session_timeout_minutes': int.parse(_sessionTimeoutController.text),
        'rate_limit': {
          'max_requests': int.parse(_maxRequestsController.text),
          'window_minutes': int.parse(_windowDurationController.text),
        },
        'feature_flags': _featureFlags,
      });
      if (!mounted) return;
      setState(() => _hasUnsavedChanges = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppCopy.text('text.platform_configuration_saved_380683d3'),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? error.message
            : 'The platform configuration could not be saved.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _markChanged(String _) {
    if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
  }

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return AdminAccessGate(
      anyCapabilities: const [AdminCapabilities.platformSystemConfigRead],
      roles: const {AdminRole.appAdmin},
      scope: AdminScope.global,
      deniedMessage: AppCopy.text(
        'text.global_runtime_configuration_is_available_only_t_669cabef',
      ),
      builder: (context) {
        if (!_hasLoaded && !_isLoading && _error == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _load(discardDraft: true),
          );
        }
        final canManage = AdminAccessScope.can(
          context,
          AdminCapabilities.platformSystemConfigManage,
        );
        final content = Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AdminPageHeader(
                title: AppCopy.text('text.platform_configuration_25fccd7c'),
                subtitle: AppCopy.text(
                  'text.global_runtime_settings_personal_mfa_and_service_e8e8cdb6',
                ),
                actions: [
                  IconButton(
                    onPressed: _isLoading ? null : _load,
                    tooltip: AppCopy.text(
                      'text.reload_platform_configuration_8cb43b29',
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  if (canManage)
                    FilledButton.icon(
                      key: const Key('save-platform-configuration'),
                      onPressed: _isLoading || !_hasUnsavedChanges
                          ? null
                          : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(AppCopy.text('text.save_4d2d5d68')),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ..._buildBodyChildren(canManage),
              const SizedBox(height: 48),
            ],
          ),
        );
        return adminPageScaffold(context, 'Platform Configuration', content);
      },
    );
  }

  List<Widget> _buildBodyChildren(bool canManage) {
    if (_isLoading && !_hasLoaded) {
      return const [
        SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null && !_hasLoaded) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error is ApiException
                      ? (_error as ApiException).message
                      : AppCopy.text(
                          'text.could_not_load_platform_configuration_b9ea7288',
                        ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _load(discardDraft: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(AppCopy.text('text.try_again_213e90fa')),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      if (!canManage)
        Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              AppCopy.text(
                'text.read_only_configuration_access_change_controls_a_5290a11e',
              ),
            ),
          ),
        ),
      if (!canManage) const SizedBox(height: 12),
      if (_error != null && _hasLoaded)
        _ConfigurationStaleBanner(
          error: _error!,
          loadedAt: _loadedAt,
          onRetry: () => _load(),
        ),
      if (_error != null && _hasLoaded) const SizedBox(height: 12),
      if (_hasUnsavedChanges)
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            AppCopy.text(
              'text.you_have_unsaved_configuration_changes_ff0f5a7b',
            ),
          ),
        ),
      PresentationPropertiesEditor(
        repository: _repository,
        canManage: canManage,
      ),
      const SizedBox(height: 16),
      PlatformConfigurationSection(
        inrLowController: _inrLowController,
        inrHighController: _inrHighController,
        sessionTimeoutController: _sessionTimeoutController,
        maxRequestsController: _maxRequestsController,
        windowDurationController: _windowDurationController,
        featureFlags: _featureFlags,
        readOnly: !canManage,
        onFieldChanged: _markChanged,
        onFeatureFlagChanged: (key, value) => setState(() {
          _featureFlags = {..._featureFlags, key: value};
          _hasUnsavedChanges = true;
        }),
      ),
    ];
  }
}

class _ConfigurationStaleBanner extends StatelessWidget {
  const _ConfigurationStaleBanner({
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
        ? 'Previously loaded configuration is shown.'
        : 'Showing configuration loaded ${MaterialLocalizations.of(context).formatFullDate(loadedAt!.toLocal())} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(loadedAt!.toLocal()))}.';
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

class PlatformConfigurationSection extends StatelessWidget {
  const PlatformConfigurationSection({
    super.key,
    required this.inrLowController,
    required this.inrHighController,
    required this.sessionTimeoutController,
    required this.maxRequestsController,
    required this.windowDurationController,
    required this.featureFlags,
    required this.onFieldChanged,
    required this.onFeatureFlagChanged,
    this.readOnly = false,
  });

  final TextEditingController inrLowController;
  final TextEditingController inrHighController;
  final TextEditingController sessionTimeoutController;
  final TextEditingController maxRequestsController;
  final TextEditingController windowDurationController;
  final Map<String, bool> featureFlags;
  final bool readOnly;
  final ValueChanged<String> onFieldChanged;
  final void Function(String key, bool value) onFeatureFlagChanged;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // INR Thresholds
        _PlatformConfigCard(
          theme,
          'Medical Thresholds',
          Icons.medical_services,
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: inrLowController,
                  enabled: !readOnly,
                  decoration: InputDecoration(
                    labelText: AppCopy.text('text.inr_critical_low_b5920f27'),
                    suffixText: 'INR',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: onFieldChanged,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = double.tryParse(v);
                    if (n == null || n < 0.5 || n > 10) {
                      return '0.5-10.0';
                    }
                    final high = double.tryParse(inrHighController.text);
                    if (high != null && n >= high) {
                      return AppCopy.text(
                        'text.must_be_below_critical_high_8fc276d7',
                      );
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: inrHighController,
                  enabled: !readOnly,
                  decoration: InputDecoration(
                    labelText: AppCopy.text('text.inr_critical_high_37f35dbb'),
                    suffixText: 'INR',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: onFieldChanged,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = double.tryParse(v);
                    if (n == null || n < 0.5 || n > 10) {
                      return '0.5-10.0';
                    }
                    final low = double.tryParse(inrLowController.text);
                    if (low != null && n <= low) {
                      return AppCopy.text(
                        'text.must_be_above_critical_low_d204284b',
                      );
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Session Settings
        _PlatformConfigCard(
          theme,
          'Session Settings',
          Icons.timer,
          TextFormField(
            controller: sessionTimeoutController,
            enabled: !readOnly,
            decoration: InputDecoration(
              labelText: AppCopy.text('text.session_timeout_2a002d78'),
              suffixText: 'min',
            ),
            keyboardType: TextInputType.number,
            onChanged: onFieldChanged,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              final n = int.tryParse(v);
              if (n == null || n < 1 || n > 1440) return '1-1440';
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),

        // Rate Limiting
        _PlatformConfigCard(
          theme,
          'Rate Limiting',
          Icons.speed,
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: maxRequestsController,
                  enabled: !readOnly,
                  decoration: InputDecoration(
                    labelText: AppCopy.text('text.max_requests_901ab1b5'),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: onFieldChanged,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = int.tryParse(v);
                    if (n == null || n < 1) return '>0';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: windowDurationController,
                  enabled: !readOnly,
                  decoration: InputDecoration(
                    labelText: AppCopy.text('text.window_duration_97c02813'),
                    suffixText: 'min',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: onFieldChanged,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = int.tryParse(v);
                    if (n == null || n < 1) return '>0';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Feature Flags
        _PlatformConfigCard(
          theme,
          'Feature Flags',
          Icons.flag,
          Column(
            children: featureFlags.entries
                .map(
                  (e) => SwitchListTile(
                    title: Text(e.key.replaceAll('_', ' ').toUpperCase()),
                    value: e.value,
                    onChanged: readOnly
                        ? null
                        : (v) => onFeatureFlagChanged(e.key, v),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _PlatformConfigCard extends StatelessWidget {
  const _PlatformConfigCard(this.theme, this.title, this.icon, this.content);

  final ThemeData theme;
  final String title;
  final IconData icon;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }
}
