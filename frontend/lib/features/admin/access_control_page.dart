import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/admin/admin_access_gate.dart';
import 'package:frontend/core/widgets/admin/admin_access_scope.dart';
import 'package:frontend/features/admin/admin_capabilities.dart';
import 'package:frontend/features/admin/admin_console_components.dart';
import 'package:frontend/features/admin/admin_step_up_dialog.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';
import 'package:frontend/features/admin/models/admin_access_model.dart';
import 'package:frontend/features/admin/models/admin_policy_ui_models.dart';
import 'package:frontend/features/admin/models/admin_role_policy_model.dart';

class AccessControlPage extends StatefulWidget {
  const AccessControlPage({super.key, this.repository});

  final AdminRepository? repository;

  @override
  State<AccessControlPage> createState() => _AccessControlPageState();
}

class _AccessControlPageState extends State<AccessControlPage> {
  late final AdminRepository _repository =
      widget.repository ?? AppDependencies.adminRepository;
  final _drafts = <AdminRole, Map<String, bool>>{};
  final _serverConflicts = <AdminRole, AdminRolePolicyModel>{};
  final _history = <AdminRole, List<AdminRolePolicyRevisionModel>>{};
  List<AdminRolePolicyModel> _policies = const [];
  Object? _error;
  bool _isLoading = false;
  bool _hasLoaded = false;
  AdminRole? _busyRole;
  AdminRole _selectedRole = AdminRole.hospitalAdmin;

  Future<void> _load({bool preserveDrafts = true}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final policies = await _repository.getRolePolicies();
      final historyEntries = await Future.wait(
        policies.map((policy) async {
          try {
            final history = await _repository.getRolePolicyHistory(policy.role);
            return MapEntry(policy.role, history);
          } catch (_) {
            return MapEntry(
              policy.role,
              const <AdminRolePolicyRevisionModel>[],
            );
          }
        }),
      );
      final histories =
          Map<AdminRole, List<AdminRolePolicyRevisionModel>>.fromEntries(
            historyEntries,
          );
      if (!mounted) return;
      setState(() {
        _policies = policies;
        _history
          ..clear()
          ..addAll(histories);
        if (!preserveDrafts) _drafts.clear();
        _error = null;
        _hasLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      final hadPolicies = _policies.isNotEmpty;
      setState(() {
        _error = error;
        // Mark loaded so first-load failures render the error panel instead of
        // scheduling infinite auto-retries from build().
        _hasLoaded = true;
      });
      if (hadPolicies && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : AppCopy.text(
                      'text.could_not_refresh_access_policies_e263575a',
                    ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return AdminAccessGate(
      anyCapabilities: const [AdminCapabilities.platformRolePolicyRead],
      roles: const {AdminRole.appAdmin},
      scope: AdminScope.global,
      deniedMessage: AppCopy.text(
        'text.access_policies_are_only_available_to_system_adm_6066b938',
      ),
      builder: (context) {
        if (!_hasLoaded && !_isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _load());
        }
        final access = AdminAccessScope.accessOf(context)!;
        final canManage =
            access.role == AdminRole.appAdmin &&
            !access.readOnly &&
            access.can(AdminCapabilities.platformRolePolicyManage);
        return adminPageScaffold(
          context,
          'Access Control',
          _buildBody(canManage),
        );
      },
    );
  }

  Widget _buildBody(bool canManage) {
    if (_isLoading && !_hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _policies.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppCopy.text('text.could_not_load_access_policies_6f70d185')),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppCopy.text('text.try_again_213e90fa')),
            ),
          ],
        ),
      );
    }

    final manageablePolicies =
        _policies
            .where(
              (policy) =>
                  policy.role == AdminRole.hospitalAdmin ||
                  policy.role == AdminRole.auditor,
            )
            .toList()
          ..sort((a, b) => a.role.index.compareTo(b.role.index));

    if (manageablePolicies.isEmpty) {
      return Center(
        child: Text(
          AppCopy.text('text.no_configurable_administrator_roles_found_c322bf'),
        ),
      );
    }

    final activeRole = manageablePolicies.any((p) => p.role == _selectedRole)
        ? _selectedRole
        : manageablePolicies.first.role;

    final selectedPolicy = manageablePolicies.firstWhere(
      (p) => p.role == activeRole,
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (manageablePolicies.length > 1) ...[
            Center(
              child: SegmentedButton<AdminRole>(
                segments: [
                  ButtonSegment<AdminRole>(
                    value: AdminRole.hospitalAdmin,
                    icon: Icon(Icons.local_hospital_outlined),
                    label: Text(AppCopy.text('text.hospital_admin_72ccad88')),
                  ),
                  ButtonSegment<AdminRole>(
                    value: AdminRole.auditor,
                    icon: Icon(Icons.visibility_outlined),
                    label: Text(AppCopy.text('text.system_auditor_e77b9212')),
                  ),
                ],
                selected: {activeRole},
                onSelectionChanged: (selected) {
                  if (selected.isNotEmpty) {
                    setState(() => _selectedRole = selected.first);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!canManage) const _PolicyReadOnlyNotice(),
          if (!canManage) const SizedBox(height: 16),
          _PolicyCard(
            policy: selectedPolicy,
            draft: _drafts[selectedPolicy.role],
            conflict: _serverConflicts[selectedPolicy.role],
            canEdit:
                canManage &&
                (selectedPolicy.role == AdminRole.hospitalAdmin ||
                    selectedPolicy.role == AdminRole.auditor),
            isBusy: _busyRole == selectedPolicy.role,
            revisions: _history[selectedPolicy.role] ?? const [],
            onCapabilityChanged: (capability, enabled) {
              final current = Map<String, bool>.from(
                _drafts[selectedPolicy.role] ?? selectedPolicy.capabilities,
              );
              setState(() {
                current[capability] = enabled;
                _drafts[selectedPolicy.role] = current;
              });
            },
            onDiscardDraft: () => setState(() {
              _drafts.remove(selectedPolicy.role);
              _serverConflicts.remove(selectedPolicy.role);
            }),
            onPreview: () => _previewAndSave(selectedPolicy),
            onRestore: (revision) =>
                _previewAndRestore(selectedPolicy, revision),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Future<void> _previewAndSave(AdminRolePolicyModel policy) async {
    final draft = _drafts[policy.role];
    if (draft == null || _mapsEqual(draft, policy.capabilities)) return;
    setState(() => _busyRole = policy.role);
    try {
      final preview = await _repository.previewRolePolicy(
        role: policy.role,
        capabilities: draft,
        expectedVersion: policy.policyVersion,
      );
      if (!mounted) return;
      final reason = await _showPreviewDialog(
        title: AppCopy.text(
          'text.review_value1_changes_495b5b12',
          arguments: {'value1': (policy.label).toString()},
        ),
        preview: preview,
        confirmLabel: AppCopy.text('text.apply_policy_b9bc679b'),
      );
      if (reason == null || !mounted) return;
      final stepUp = await requestAdminStepUp(
        context,
        action: 'access policy update',
      );
      if (stepUp == null || !mounted) return;
      try {
        await _repository.updateRolePolicyV2(
          role: policy.role,
          capabilities: draft,
          expectedVersion: policy.policyVersion,
          changeReason: reason,
          stepUp: stepUp,
        );
        if (!mounted) return;
        setState(() {
          _drafts.remove(policy.role);
          _serverConflicts.remove(policy.role);
        });
        await AdminAccessScope.of(
          context,
          listen: false,
        ).refreshAfterPolicyUpdate();
        await _load(preserveDrafts: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppCopy.text('text.access_policy_updated_16d765d6'),
              ),
            ),
          );
        }
      } catch (error) {
        await _handleMutationError(policy, error);
      }
    } on ApiException catch (error) {
      if (error.isConflict) {
        await _recordConflict(policy);
      } else if (mounted) {
        _showSafeError(error);
      }
    } catch (_) {
      if (mounted) {
        _showSafeErrorMessage(
          'The preview could not be loaded. Your draft was kept.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyRole = null);
    }
  }

  Future<void> _previewAndRestore(
    AdminRolePolicyModel policy,
    AdminRolePolicyRevisionModel revision,
  ) async {
    setState(() => _busyRole = policy.role);
    try {
      final preview = await _repository.previewRolePolicyRestore(
        role: policy.role,
        revisionId: revision.id,
        expectedVersion: policy.policyVersion,
      );
      if (!mounted) return;
      final reason = await _showPreviewDialog(
        title: AppCopy.text(
          'text.restore_value1_to_version_value2_213b2944',
          arguments: {
            'value1': (policy.label).toString(),
            'value2': (revision.newPolicyVersion).toString(),
          },
        ),
        preview: preview,
        confirmLabel: AppCopy.text('text.restore_as_new_version_4ff39605'),
      );
      if (reason == null || !mounted) return;
      final stepUp = await requestAdminStepUp(
        context,
        action: 'access policy restore',
      );
      if (stepUp == null || !mounted) return;
      try {
        await _repository.restoreRolePolicy(
          role: policy.role,
          revisionId: revision.id,
          expectedVersion: policy.policyVersion,
          changeReason: reason,
          stepUp: stepUp,
        );
        if (!mounted) return;
        await AdminAccessScope.of(
          context,
          listen: false,
        ).refreshAfterPolicyUpdate();
        await _load(preserveDrafts: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppCopy.text(
                  'text.policy_restored_as_a_new_policy_version_54cc29d4',
                ),
              ),
            ),
          );
        }
      } catch (error) {
        await _handleMutationError(policy, error);
      }
    } on ApiException catch (error) {
      if (error.isConflict) {
        await _recordConflict(policy);
      } else if (mounted) {
        _showSafeError(error);
      }
    } catch (_) {
      if (mounted) {
        _showSafeErrorMessage(
          'The restore preview could not be loaded. No changes were made.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyRole = null);
    }
  }

  Future<String?> _showPreviewDialog({
    required String title,
    required AdminRolePolicyPreviewModel preview,
    required String confirmLabel,
  }) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppCopy.text(
                      'text.value1_active_administrator_account_s_will_use_t_3b0fe988',
                      arguments: {
                        'value1': (preview.affectedActiveAccounts).toString(),
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PreviewChanges(
                    label: AppCopy.text('text.added_b35c3185'),
                    capabilities: preview.added,
                    icon: Icons.add_circle_outline,
                  ),
                  const SizedBox(height: 12),
                  _PreviewChanges(
                    label: AppCopy.text('text.removed_70a26e7b'),
                    capabilities: preview.removed,
                    icon: Icons.remove_circle_outline,
                  ),
                  if (preview.warnings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    for (final warning in preview.warnings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(warning)),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('policy-change-reason'),
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: AppCopy.text(
                        'text.reason_for_this_change_58d3beea',
                      ),
                      helperText: AppCopy.text(
                        'text.the_reason_is_stored_in_permanent_policy_history_fbe1e728',
                      ),
                    ),
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    validator: (value) =>
                        value == null || value.trim().length < 3
                        ? 'Enter at least 3 characters.'
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppCopy.text('text.cancel_35afca3b')),
          ),
          FilledButton(
            key: const Key('confirm-policy-change'),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, reasonController.text.trim());
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    reasonController.dispose();
    return result;
  }

  Future<void> _handleMutationError(
    AdminRolePolicyModel policy,
    Object error,
  ) async {
    if (error is ApiException && error.isConflict) {
      await _recordConflict(policy);
      return;
    }
    if (mounted) {
      _showSafeErrorMessage(
        error is ApiException
            ? '${error.message} Your draft was kept.'
            : 'The policy could not be updated. Your draft was kept.',
      );
    }
  }

  Future<void> _recordConflict(AdminRolePolicyModel policy) async {
    try {
      final current = await _repository.getRolePolicy(policy.role);
      if (!mounted) return;
      setState(() {
        _serverConflicts[policy.role] = current;
        _policies = _policies
            .map((item) => item.role == policy.role ? current : item)
            .toList(growable: false);
      });
    } catch (_) {
      if (!mounted) return;
    }
    if (mounted) {
      _showSafeErrorMessage(
        'This policy changed on the server. Your local draft was kept so you can compare it with the current policy.',
      );
    }
  }

  void _showSafeError(ApiException error) {
    _showSafeErrorMessage(error.message);
  }

  void _showSafeErrorMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.policy,
    required this.draft,
    required this.conflict,
    required this.canEdit,
    required this.isBusy,
    required this.revisions,
    required this.onCapabilityChanged,
    required this.onDiscardDraft,
    required this.onPreview,
    required this.onRestore,
  });

  final AdminRolePolicyModel policy;
  final Map<String, bool>? draft;
  final AdminRolePolicyModel? conflict;
  final bool canEdit;
  final bool isBusy;
  final List<AdminRolePolicyRevisionModel> revisions;
  final void Function(String capability, bool enabled) onCapabilityChanged;
  final VoidCallback onDiscardDraft;
  final VoidCallback onPreview;
  final ValueChanged<AdminRolePolicyRevisionModel> onRestore;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final theme = Theme.of(context);
    final values = draft ?? policy.capabilities;
    final hasDraft = draft != null && !_mapsEqual(draft!, policy.capabilities);
    final groups = <String, List<String>>{};
    for (final capability in values.keys) {
      final area = adminCapabilityInfo[capability]?.area ?? 'Other';
      groups.putIfAbsent(area, () => []).add(capability);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Icon(
                    policy.role == AdminRole.auditor
                        ? Icons.visibility_outlined
                        : Icons.admin_panel_settings_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        policy.label,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        policy.description.isEmpty
                            ? _roleDescription(policy.role)
                            : policy.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    AppCopy.text(
                      'text.version_value1_d9b2c281',
                      arguments: {'value1': (policy.policyVersion).toString()},
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  AppCopy.text(
                    'text.value1_active_account_s_133c9d0a',
                    arguments: {
                      'value1': (policy.activeAccountCount).toString(),
                    },
                  ),
                ),
                Text(
                  policy.updatedAt == null
                      ? AppCopy.text('text.last_change_unavailable_397c6ee1')
                      : AppCopy.text(
                          'text.changed_value1_c9c687c5',
                          arguments: {
                            'value1': (_formatDate(
                              policy.updatedAt!,
                            )).toString(),
                          },
                        ),
                ),
                if (policy.changeReason != null)
                  Text(
                    AppCopy.text(
                      'text.reason_value1_f38c1387',
                      arguments: {'value1': (policy.changeReason).toString()},
                    ),
                  ),
              ],
            ),
            if (conflict != null) ...[
              const SizedBox(height: 14),
              Material(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sync_problem_outlined,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppCopy.text(
                            'text.server_version_value1_is_newer_your_local_draft__7add2b7f',
                            arguments: {
                              'value1': (conflict!.policyVersion).toString(),
                            },
                          ),
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Divider(height: 28),
            for (final group in groups.entries) ...[
              Text(
                group.key,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              for (final capability in group.value)
                _CapabilityRow(
                  capability: capability,
                  enabled: values[capability] == true,
                  editable: canEdit,
                  onChanged: (value) => onCapabilityChanged(capability, value),
                ),
              const SizedBox(height: 12),
            ],
            if (canEdit && hasDraft) ...[
              const Divider(),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: Key('preview-${policy.role.wireValue}'),
                    onPressed: isBusy ? null : onPreview,
                    icon: isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.preview_outlined),
                    label: Text(AppCopy.text('text.preview_changes_964c14fa')),
                  ),
                  TextButton(
                    onPressed: isBusy ? null : onDiscardDraft,
                    child: Text(AppCopy.text('text.discard_draft_8789fd5e')),
                  ),
                ],
              ),
            ],
            if (revisions.isNotEmpty) ...[
              const Divider(height: 28),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(AppCopy.text('text.policy_history_4bfeb417')),
                subtitle: Text(
                  AppCopy.text(
                    'text.value1_recorded_change_s_3285c95b',
                    arguments: {'value1': (revisions.length).toString()},
                  ),
                ),
                children: [
                  for (final revision in revisions)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_rounded),
                      title: Text(
                        AppCopy.text(
                          'text.version_value1_value2_886b0694',
                          arguments: {
                            'value1': (revision.newPolicyVersion).toString(),
                            'value2': (revision.changeReason).toString(),
                          },
                        ),
                      ),
                      subtitle: Text(
                        AppCopy.text(
                          'text.value1_active_account_s_affected_value2_2a1f78b5',
                          arguments: {
                            'value1': (revision.affectedActiveAccountCount)
                                .toString(),
                            'value2':
                                (revision.createdAt == null
                                        ? ''
                                        : ' • ${_formatDate(revision.createdAt!)}')
                                    .toString(),
                          },
                        ),
                      ),
                      trailing:
                          canEdit &&
                              revision.newPolicyVersion < policy.policyVersion
                          ? TextButton(
                              onPressed: isBusy
                                  ? null
                                  : () => onRestore(revision),
                              child: Text(AppCopy.text('text.restore_ff87f71')),
                            )
                          : null,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({
    required this.capability,
    required this.enabled,
    required this.editable,
    required this.onChanged,
  });

  final String capability;
  final bool enabled;
  final bool editable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final info = adminCapabilityInfo[capability];
    final title = info?.label ?? capability;
    final description = info?.description ?? capability;
    if (editable) {
      return Semantics(
        label: AppCopy.text(
          'text.value1_permission_value2_b0226bc1',
          arguments: {
            'value1': (title).toString(),
            'value2': (enabled ? 'Enabled' : 'Disabled').toString(),
          },
        ),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(description),
          value: enabled,
          onChanged: onChanged,
        ),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        enabled ? Icons.check_circle_outline : Icons.remove_circle_outline,
      ),
      title: Text(title),
      subtitle: Text(description),
      trailing: Text(
        enabled
            ? AppCopy.text('text.included_b8adfdd9')
            : AppCopy.text('text.not_included_34c9f84e'),
      ),
    );
  }
}

class _PreviewChanges extends StatelessWidget {
  const _PreviewChanges({
    required this.label,
    required this.capabilities,
    required this.icon,
  });

  final String label;
  final List<String> capabilities;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        if (capabilities.isEmpty)
          Text(AppCopy.text('text.none_304ff7fb'))
        else
          for (final capability in capabilities)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, size: 20),
              title: Text(adminCapabilityInfo[capability]?.label ?? capability),
            ),
      ],
    );
  }
}

class _PolicyReadOnlyNotice extends StatelessWidget {
  const _PolicyReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.visibility_outlined),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                AppCopy.text(
                  'text.read_only_policy_review_system_auditors_can_insp_90499975',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _mapsEqual(Map<String, bool> a, Map<String, bool> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

String _roleDescription(AdminRole role) => switch (role) {
  AdminRole.appAdmin =>
    'Protected global platform authority. This policy cannot be edited in the portal.',
  AdminRole.hospitalAdmin =>
    'Tenant-scoped operational authority for one assigned hospital.',
  AdminRole.auditor =>
    'Configurable global read access. System Auditors remain hard read-only.',
};

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
