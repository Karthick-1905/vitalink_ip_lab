import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/auth/session_expiry_handler.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/admin/admin_access_gate.dart';
import 'package:frontend/features/admin/admin_console_components.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';
import 'package:frontend/features/admin/models/admin_mfa_model.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key, this.repository});

  final AdminRepository? repository;

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  late final AdminRepository _repository =
      widget.repository ?? AppDependencies.adminRepository;
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  AdminTotpEnrollment? _enrollment;
  AdminTotpStatus? _status;
  bool _isLoading = false;
  bool _isStarting = false;
  bool _isActivating = false;
  bool _hasLoaded = false;
  bool _hasAttemptedLoad = false;
  Object? _loadError;
  DateTime? _statusLoadedAt;
  List<Map<String, dynamic>> _sessions = const [];
  bool _sessionsLoading = false;
  Object? _sessionsError;

  Future<void> _loadSessions() async {
    if (_sessionsLoading) return;
    setState(() {
      _sessionsLoading = true;
      _sessionsError = null;
    });
    try {
      final sessions = await _repository.getOwnSessions();
      if (mounted) setState(() => _sessions = sessions);
    } catch (error) {
      if (mounted) setState(() => _sessionsError = error);
    } finally {
      if (mounted) setState(() => _sessionsLoading = false);
    }
  }

  Future<void> _revokeSession(Map<String, dynamic> session) async {
    final current = session['current'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          current ? 'Sign out this session?' : 'Revoke this session?',
        ),
        content: Text(
          current
              ? 'You will need to sign in again.'
              : 'That device will need to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(current ? 'Sign out' : 'Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repository.revokeOwnSession(session['id'] as String);
      if (!mounted) return;
      if (current) {
        await SessionExpiryHandler.clearSessionAndRedirectToLogin();
      } else {
        await _loadSessions();
      }
    } catch (error) {
      if (mounted) _showError(error, 'Could not revoke the session.');
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final status = await _repository.getAdminTotpStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loadError = null;
        _statusLoadedAt = DateTime.now();
        if (status.isEnabled) {
          _enrollment = null;
          _codeController.clear();
        }
        _hasLoaded = true;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loadError = error);
        if (_hasLoaded) _showError(error, 'Could not refresh your MFA status.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasAttemptedLoad = true;
        });
      }
    }
  }

  Future<void> _startSetup() async {
    setState(() => _isStarting = true);
    try {
      final enrollment = await _repository.setupAdminTotp();
      if (!mounted) return;
      setState(() {
        _enrollment = enrollment;
        _codeController.clear();
        _status = AdminTotpStatus(
          factorType: enrollment.factorType,
          status: 'PENDING',
          enabled: false,
        );
      });
    } catch (error) {
      if (mounted) _showError(error, 'Could not start authenticator setup.');
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isActivating = true);
    try {
      final activation = await _repository.activateAdminTotp(
        _codeController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _enrollment = null;
        _codeController.clear();
        _status = AdminTotpStatus(
          factorType: activation.factorType,
          status: activation.status,
          enabled: activation.isEnabled,
          activatedAt: DateTime.now(),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authenticator MFA enabled.')),
      );
    } catch (error) {
      if (mounted) _showError(error, 'Could not activate authenticator MFA.');
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  Future<void> _copy(String label, String value) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  void _showError(Object error, String fallback) {
    final message = error is ApiException ? error.message : fallback;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AdminAccessGate(
      builder: (context) {
        if (!_hasAttemptedLoad && !_isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatus());
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadSessions());
        }
        final content = ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminPageHeader(
              title: 'Personal Security',
              subtitle:
                  'This authenticator belongs to your own administrator account. It is separate from platform configuration and health access.',
              actions: [
                IconButton(
                  onPressed: _isLoading ? null : _loadStatus,
                  tooltip: 'Refresh MFA status',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading && !_hasLoaded)
              const Center(child: CircularProgressIndicator())
            else if (_loadError != null && !_hasLoaded)
              _MfaStatusLoadError(error: _loadError!, onRetry: _loadStatus)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loadError != null)
                    _MfaStatusStaleBanner(
                      error: _loadError!,
                      loadedAt: _statusLoadedAt,
                      onRetry: _loadStatus,
                    ),
                  if (_loadError != null) const SizedBox(height: 12),
                  AccountSecurityMfaSection(
                    formKey: _formKey,
                    codeController: _codeController,
                    enrollment: _enrollment,
                    status: _status,
                    isStartingTotp: _isStarting,
                    isActivatingTotp: _isActivating,
                    onStartSetup: _startSetup,
                    onActivate: _activate,
                    onCancelSetup: () => setState(() {
                      _enrollment = null;
                      _codeController.clear();
                    }),
                    onCopySetupValue: _copy,
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Active sessions',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: _sessionsLoading ? null : _loadSessions,
                          tooltip: 'Refresh sessions',
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Review devices signed in to your account. Revoke any session you do not recognize.',
                    ),
                    if (_sessionsLoading) const LinearProgressIndicator(),
                    if (_sessionsError != null)
                      Text('Could not load sessions. Try refreshing.'),
                    if (!_sessionsLoading &&
                        _sessionsError == null &&
                        _sessions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text('No active sessions found.'),
                      ),
                    for (final session in _sessions)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.devices_outlined),
                        title: Text(
                          session['current'] == true
                              ? 'This session'
                              : (session['user_agent'] as String? ??
                                    'Unknown device'),
                        ),
                        subtitle: Text(
                          'Last used: ${session['last_used_at'] ?? 'Unknown'}\nIP: ${session['ip_address'] ?? 'Unknown'}',
                        ),
                        isThreeLine: true,
                        trailing: TextButton(
                          onPressed: () => _revokeSession(session),
                          child: Text(
                            session['current'] == true ? 'Sign out' : 'Revoke',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
        return adminPageScaffold(context, 'Personal Security', content);
      },
    );
  }
}

class _MfaStatusLoadError extends StatelessWidget {
  const _MfaStatusLoadError({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Could not load your MFA status.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MfaStatusStaleBanner extends StatelessWidget {
  const _MfaStatusStaleBanner({
    required this.error,
    required this.loadedAt,
    required this.onRetry,
  });

  final Object error;
  final DateTime? loadedAt;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final timestamp = loadedAt == null
        ? 'Previously loaded MFA status is shown.'
        : 'Showing MFA status loaded ${MaterialLocalizations.of(context).formatFullDate(loadedAt!.toLocal())} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(loadedAt!.toLocal()))}.';
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
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class AccountSecurityMfaSection extends StatelessWidget {
  const AccountSecurityMfaSection({
    super.key,
    required this.formKey,
    required this.codeController,
    required this.enrollment,
    required this.status,
    required this.isStartingTotp,
    required this.isActivatingTotp,
    required this.onStartSetup,
    required this.onActivate,
    required this.onCancelSetup,
    required this.onCopySetupValue,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController codeController;
  final AdminTotpEnrollment? enrollment;
  final AdminTotpStatus? status;
  final bool isStartingTotp;
  final bool isActivatingTotp;
  final VoidCallback onStartSetup;
  final VoidCallback onActivate;
  final VoidCallback onCancelSetup;
  final Future<void> Function(String label, String value) onCopySetupValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentEnrollment = enrollment;
    final hasPendingSetup = currentEnrollment != null;
    final isEnabled = status?.isEnabled ?? false;
    final statusLabel = isEnabled
        ? 'Enabled'
        : hasPendingSetup || (status?.isPending ?? false)
        ? 'Setup pending'
        : 'Not set up';
    final statusColor = isEnabled
        ? Colors.green
        : hasPendingSetup || (status?.isPending ?? false)
        ? Colors.orange
        : theme.colorScheme.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Admin Authenticator MFA',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  Chip(
                    label: Text(statusLabel),
                    backgroundColor: statusColor.withValues(alpha: 0.1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Use an authenticator app for admin login challenges.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (isEnabled)
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.verified_user_rounded),
                  label: const Text('Authenticator MFA is enabled'),
                )
              else if (!hasPendingSetup)
                FilledButton.icon(
                  onPressed: isStartingTotp ? null : onStartSetup,
                  icon: isStartingTotp
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Start authenticator setup'),
                ),
              if (hasPendingSetup) ...[
                const SizedBox(height: 4),
                Text(
                  'Scan this QR code with your authenticator app.',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: currentEnrollment.otpauthUrl,
                      version: QrVersions.auto,
                      size: 208,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                      semanticsLabel: 'Authenticator app setup QR code',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'If your app cannot scan a code, use the setup key below instead.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _SetupValueTile(
                  label: 'Setup key',
                  value: currentEnrollment.secret,
                  onCopy: () =>
                      onCopySetupValue('Setup key', currentEnrollment.secret),
                ),
                const SizedBox(height: 10),
                _SetupValueTile(
                  label: 'otpauth URL',
                  value: currentEnrollment.otpauthUrl,
                  onCopy: () => onCopySetupValue(
                    'otpauth URL',
                    currentEnrollment.otpauthUrl,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Authenticator code',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  validator: (value) {
                    final code = value?.trim() ?? '';
                    if (code.isEmpty) return 'Code is required';
                    if (code.length != 6) return 'Enter 6 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isActivatingTotp ? null : onActivate,
                        icon: isActivatingTotp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.verified_user_rounded),
                        label: const Text('Activate'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isActivatingTotp ? null : onCancelSetup,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupValueTile extends StatelessWidget {
  const _SetupValueTile({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  maxLines: 2,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy',
          ),
        ],
      ),
    );
  }
}
