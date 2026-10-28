import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/admin/admin_access_gate.dart';
import 'package:frontend/core/widgets/admin/admin_access_scope.dart';
import 'package:frontend/core/widgets/admin/admin_mutation_dialog.dart';
import 'package:frontend/features/admin/admin_capabilities.dart';
import 'package:frontend/features/admin/admin_console_components.dart';
import 'package:frontend/features/admin/admin_step_up_dialog.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';
import 'package:frontend/features/admin/models/admin_access_model.dart';
import 'package:frontend/features/admin/models/admin_account_model.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AdminAccountsPage extends StatefulWidget {
  const AdminAccountsPage({super.key, this.repository});

  final AdminRepository? repository;

  @override
  State<AdminAccountsPage> createState() => _AdminAccountsPageState();
}

class _AdminAccountsPageState extends State<AdminAccountsPage> {
  late final AdminRepository _repository =
      widget.repository ?? AppDependencies.adminRepository;
  final _searchController = TextEditingController();
  List<AdminAccountModel> _accounts = const [];
  Object? _error;
  bool _isLoading = false;
  bool _hasLoaded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (!silent) _error = null;
    });
    try {
      final accounts = await _repository.getAdminAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _error = null;
        _hasLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        // Still mark loaded so the error panel (not an empty list) is rendered,
        // and so build() does not schedule infinite auto-retries.
        _hasLoaded = true;
      });
      if (silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : AppCopy.text(
                      'text.could_not_refresh_administrator_accounts_2ef6b323',
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
      anyCapabilities: const [AdminCapabilities.platformAdminAccountsRead],
      roles: const {AdminRole.appAdmin},
      scope: AdminScope.global,
      deniedMessage: AppCopy.text(
        'text.only_an_application_admin_can_manage_hospital_ad_ffef5555',
      ),
      builder: (context) {
        if (!_hasLoaded && !_isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _load());
        }
        final canManage = AdminAccessScope.can(
          context,
          AdminCapabilities.platformAdminAccountsManage,
        );
        final query = _searchController.text.trim().toLowerCase();
        final visibleAccounts = _accounts
            .where((account) {
              return "${(account.name).toString()} ${(account.loginId).toString()} ${(account.email ?? '').toString()} ${(account.role.wireValue).toString()}"
                  .toLowerCase()
                  .contains(query);
            })
            .toList(growable: false);

        final body = AdminListShell(
          title: AppCopy.text('text.administrator_accounts_fd0d4536'),
          subtitle: AppCopy.text(
            'text.manage_hospital_admin_and_system_auditor_account_334dcb8f',
          ),
          searchController: _searchController,
          searchHint: AppCopy.text('text.search_administrators_4fa03bc1'),
          onSearch: () => setState(() {}),
          actions: [
            if (canManage)
              FilledButton.icon(
                key: const Key('invite-admin-account'),
                onPressed: () => _showAccountDialog(),
                icon: const Icon(Icons.person_add_alt_rounded),
                label: Text(AppCopy.text('text.invite_59997b30')),
              ),
          ],
          child: _buildBody(visibleAccounts, canManage),
        );
        return adminPageScaffold(context, 'Administrator Accounts', body);
      },
    );
  }

  Widget _buildBody(List<AdminAccountModel> accounts, bool canManage) {
    if (_isLoading && !_hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _accounts.isEmpty) {
      final message = _error is ApiException
          ? (_error as ApiException).message
          : 'Could not load administrator accounts.';
      return _InlineLoadError(message: message, onRetry: _load);
    }
    if (accounts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 120),
            Icon(Icons.manage_accounts_outlined, size: 48),
            SizedBox(height: 12),
            Center(
              child: Text(
                AppCopy.text('text.no_administrator_accounts_found_1758f815'),
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                AppCopy.text(
                  'text.this_list_only_shows_hospital_admin_and_system_a_9f17af0e',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: accounts.length,
        itemBuilder: (context, index) {
          final account = accounts[index];
          return AdminRecordCard(
            icon: account.role == AdminRole.auditor
                ? Icons.visibility_outlined
                : Icons.admin_panel_settings_outlined,
            title: account.name,
            badge: adminRoleLabel(account.role),
            details: [
              AdminDetail(Icons.login_rounded, account.loginId),
              if (account.email != null)
                AdminDetail(Icons.mail_outline_rounded, account.email!),
              AdminDetail(
                account.hasBrokenHospitalAssignment
                    ? Icons.warning_amber_rounded
                    : Icons.local_hospital_outlined,
                account.hospitalDisplayLabel,
              ),
              AdminDetail(
                account.isActive
                    ? Icons.check_circle_outline
                    : Icons.block_outlined,
                account.isActive ? 'Active' : 'Suspended',
              ),
              AdminDetail(
                Icons.phonelink_lock_outlined,
                account.mfaEnabled ? 'MFA enabled' : 'MFA not enabled',
              ),
              if (account.assignmentError != null)
                AdminDetail(
                  Icons.error_outline_rounded,
                  account.assignmentError!,
                ),
            ],
            menu: canManage
                ? [
                    PopupMenuItem<String>(
                      value: 'edit',
                      onTap: () => Future.microtask(
                        () => _showAccountDialog(account: account),
                      ),
                      child: Text(
                        AppCopy.text('text.edit_role_or_scope_a5820a28'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'status',
                      onTap: () =>
                          Future.microtask(() => _toggleStatus(account)),
                      child: Text(
                        account.isActive
                            ? AppCopy.text('text.suspend_e196ab03')
                            : AppCopy.text('text.restore_ff87f71'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'reset-mfa',
                      onTap: () => Future.microtask(() => _resetMfa(account)),
                      child: Text(
                        AppCopy.text('text.reset_authenticator_f73f59c7'),
                      ),
                    ),
                  ]
                : const [],
          );
        },
      ),
    );
  }

  Future<void> _showAccountDialog({AdminAccountModel? account}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: account?.name ?? '');
    final emailController = TextEditingController(
      text: account?.email ?? account?.loginId ?? '',
    );
    var role = account?.role ?? AdminRole.hospitalAdmin;
    String? hospitalId = account?.hospital?.id;
    var saving = false;
    final hospitalsFuture = _repository.getHospitals(status: 'active');

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => FutureBuilder<Map<String, dynamic>>(
        future: hospitalsFuture,
        builder: (context, snapshot) {
          final hospitals = List<Map<String, dynamic>>.from(
            (snapshot.data?['hospitals'] as List? ?? const []).map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          );
          // Include the account's current hospital even when it is no longer
          // active so DropdownButtonFormField never receives a missing value.
          final currentHospitalId = account?.hospital?.id;
          final hasCurrentHospital =
              currentHospitalId != null &&
              hospitals.any(
                (hospital) =>
                    '${hospital['id'] ?? hospital['_id']}' == currentHospitalId,
              );
          if (currentHospitalId != null &&
              currentHospitalId.isNotEmpty &&
              !hasCurrentHospital) {
            hospitals.insert(0, {
              'id': currentHospitalId,
              'name':
                  account?.hospital?.name ??
                  account?.hospital?.code ??
                  currentHospitalId,
              'code': account?.hospital?.code,
              'status': 'inactive',
            });
          }
          // Clear selection if the current id is still not representable.
          final selectableIds = hospitals
              .map((hospital) => '${hospital['id'] ?? hospital['_id']}')
              .toSet();
          final effectiveHospitalId =
              hospitalId != null && selectableIds.contains(hospitalId)
              ? hospitalId
              : null;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final needsHospital = role == AdminRole.hospitalAdmin;
              final scopeChanged =
                  account != null &&
                  (role != account.role ||
                      (role == AdminRole.hospitalAdmin &&
                          hospitalId != account.hospital?.id));
              return AdminMutationDialog(
                busy: saving,
                child: AlertDialog(
                  title: Text(
                    account == null
                        ? AppCopy.text('text.invite_administrator_636ddded')
                        : AppCopy.text('text.edit_administrator_ddeda1a0'),
                  ),
                  content: SizedBox(
                    width: 460,
                    child: Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              key: const Key('admin-account-name'),
                              controller: nameController,
                              enabled: !saving,
                              decoration: InputDecoration(
                                labelText: AppCopy.text(
                                  'text.full_name_9010932f',
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Enter the administrator name.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const Key('admin-account-email'),
                              controller: emailController,
                              enabled: account == null && !saving,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: AppCopy.text('text.email_43352167'),
                                helperText: AppCopy.text(
                                  'text.this_email_is_also_the_administrator_sign_in_id_1b607dda',
                                ),
                              ),
                              validator: (value) =>
                                  value == null ||
                                      !RegExp(
                                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                      ).hasMatch(value.trim())
                                  ? 'Enter a valid email address.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<AdminRole>(
                              key: const Key('admin-account-role'),
                              initialValue: role,
                              decoration: InputDecoration(
                                labelText: AppCopy.text('text.role_902b7e39'),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: AdminRole.hospitalAdmin,
                                  child: Text(
                                    AppCopy.text(
                                      'text.hospital_admin_72ccad88',
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: AdminRole.auditor,
                                  child: Text(
                                    AppCopy.text(
                                      'text.system_auditor_e77b9212',
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: saving
                                  ? null
                                  : (value) => setDialogState(() {
                                      role = value ?? role;
                                      if (role == AdminRole.auditor) {
                                        hospitalId = null;
                                      }
                                    }),
                            ),
                            if (needsHospital) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: const Key('admin-account-hospital'),
                                initialValue: effectiveHospitalId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: AppCopy.text(
                                    'text.active_hospital_140b06cb',
                                  ),
                                  helperText:
                                      hasCurrentHospital ||
                                          account?.hospital == null
                                      ? AppCopy.text(
                                          'text.hospital_admin_access_is_limited_to_this_hospita_31d77d07',
                                        )
                                      : AppCopy.text(
                                          'text.the_currently_assigned_hospital_is_inactive_sele_cf580652',
                                        ),
                                  errorText: snapshot.hasError
                                      ? AppCopy.text(
                                          'text.could_not_load_active_hospitals_2a877a3c',
                                        )
                                      : null,
                                ),
                                items: hospitals
                                    .map((hospital) {
                                      final id =
                                          '${hospital['id'] ?? hospital['_id']}';
                                      final status =
                                          '${hospital['status'] ?? 'active'}';
                                      final label =
                                          '${hospital['name'] ?? hospital['code'] ?? id}';
                                      return DropdownMenuItem(
                                        value: id,
                                        child: Text(
                                          status == 'active'
                                              ? label
                                              : AppCopy.text(
                                                  'text.value1_inactive_befcbba7',
                                                  arguments: {
                                                    'value1': (label)
                                                        .toString(),
                                                  },
                                                ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    })
                                    .toList(growable: false),
                                onChanged: snapshot.hasData && !saving
                                    ? (value) => setDialogState(
                                        () => hospitalId = value,
                                      )
                                    : null,
                                validator: (value) =>
                                    needsHospital &&
                                        (value == null || value.isEmpty)
                                    ? 'Select an active hospital.'
                                    : null,
                              ),
                            ],
                            if (scopeChanged) ...[
                              const SizedBox(height: 16),
                              Text(
                                AppCopy.text(
                                  'text.access_impact_value1_value2_value3_value4_all_ac_d0e7a3b0',
                                  arguments: {
                                    'value1': (adminRoleLabel(
                                      account.role,
                                    )).toString(),
                                    'value2': (account.hospitalDisplayLabel)
                                        .toString(),
                                    'value3': (adminRoleLabel(role)).toString(),
                                    'value4':
                                        (role == AdminRole.auditor
                                                ? 'Global'
                                                : (hospitals
                                                          .where(
                                                            (h) =>
                                                                '${h['id'] ?? h['_id']}' ==
                                                                hospitalId,
                                                          )
                                                          .map(
                                                            (h) =>
                                                                '${h['name'] ?? h['code'] ?? hospitalId}',
                                                          )
                                                          .firstOrNull ??
                                                      'Select a hospital'))
                                            .toString(),
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => Navigator.pop(dialogContext),
                      child: Text(AppCopy.text('text.cancel_35afca3b')),
                    ),
                    FilledButton(
                      key: const Key('save-admin-account'),
                      onPressed: saving || (needsHospital && !snapshot.hasData)
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              final stepUp = await requestAdminStepUp(
                                dialogContext,
                                action: account == null
                                    ? 'administrator invitation'
                                    : 'administrator account changes',
                              );
                              if (stepUp == null) return;
                              setDialogState(() => saving = true);
                              // System Auditors are global: omit hospital_id entirely.
                              // Sending null fails backend Zod validation
                              // (hospital_id is string|undefined, not null).
                              final payload = <String, dynamic>{
                                'name': nameController.text.trim(),
                                'role': role.wireValue,
                                if (role == AdminRole.hospitalAdmin)
                                  'hospital_id': hospitalId,
                                if (account == null)
                                  'email': emailController.text.trim(),
                              };
                              try {
                                final result = account == null
                                    ? await _repository.createAdminAccount(
                                        payload,
                                        stepUp: stepUp,
                                      )
                                    : await _repository.updateAdminAccount(
                                        account.id,
                                        payload,
                                        stepUp: stepUp,
                                      );
                                if (!dialogContext.mounted) return;
                                Navigator.pop(dialogContext);
                                if (account == null) {
                                  await _showInvitationResult(
                                    result.temporaryPassword,
                                  );
                                }
                                if (mounted) await _load(silent: true);
                                if (!mounted) return;
                                if (account != null) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppCopy.text(
                                          'text.administrator_updated_363a2a15',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              } catch (error) {
                                if (dialogContext.mounted) {
                                  _showSafeError(dialogContext, error);
                                  setDialogState(() => saving = false);
                                }
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              account == null
                                  ? AppCopy.text('text.invite_59997b30')
                                  : AppCopy.text('text.save_4d2d5d68'),
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
    nameController.dispose();
    emailController.dispose();
  }

  Future<void> _toggleStatus(AdminAccountModel account) async {
    final action = account.isActive ? 'Suspend' : 'Restore';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$action ${account.name}?'),
        content: Text(
          account.isActive
              ? AppCopy.text(
                  'text.suspending_this_account_signs_the_administrator__e924a9d8',
                )
              : AppCopy.text(
                  'text.restoring_this_account_allows_the_administrator__192c2a4c',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppCopy.text('text.cancel_35afca3b')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final stepUp = await requestAdminStepUp(
      context,
      action: '$action administrator account',
    );
    if (stepUp == null || !mounted) return;
    try {
      await _repository.updateAdminAccount(account.id, {
        'is_active': !account.isActive,
      }, stepUp: stepUp);
      await _load();
    } catch (error) {
      if (mounted) _showSafeError(context, error);
    }
  }

  Future<void> _resetMfa(AdminAccountModel account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppCopy.text('text.reset_authenticator_30baa168')),
        content: Text(
          AppCopy.text(
            'text.this_replaces_value1_s_authenticator_setup_and_s_789f6359',
            arguments: {'value1': (account.name).toString()},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppCopy.text('text.cancel_35afca3b')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppCopy.text('text.reset_authenticator_f73f59c7')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final stepUp = await requestAdminStepUp(
      context,
      action: 'authenticator reset',
    );
    if (stepUp == null || !mounted) return;
    try {
      final result = await _repository.resetAdminAccountMfa(
        account.id,
        stepUp: stepUp,
      );
      if (!mounted) return;
      final setup = result['setup'] is Map
          ? Map<String, dynamic>.from(result['setup'] as Map)
          : result;
      await _showMfaResetResult(account.name, setup);
      await _load();
    } catch (error) {
      if (mounted) _showSafeError(context, error);
    }
  }

  Future<void> _showInvitationResult(String? temporaryPassword) {
    return showAdminCredentialResult(
      context,
      title: AppCopy.text('text.administrator_invited_17211381'),
      successMessage: temporaryPassword == null
          ? AppCopy.text(
              'text.the_administrator_must_complete_the_required_sig_72bc9a10',
            )
          : AppCopy.text(
              'text.share_this_temporary_password_securely_it_is_sho_da587255',
            ),
      temporaryPassword: temporaryPassword,
    );
  }

  Future<void> _showMfaResetResult(
    String accountName,
    Map<String, dynamic> setup,
  ) {
    final otpauthUrl = '${setup['otpauth_url'] ?? setup['otpauthUrl'] ?? ''}';
    final secret = '${setup['secret'] ?? ''}';
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppCopy.text('text.new_authenticator_setup_7b40ba13')),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppCopy.text(
                  'text.value1_must_enroll_this_replacement_before_signi_6d8eb265',
                  arguments: {'value1': (accountName).toString()},
                ),
              ),
              if (otpauthUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: QrImageView(
                    data: otpauthUrl,
                    size: 200,
                    backgroundColor: Colors.white,
                    semanticsLabel: 'Replacement authenticator setup QR code',
                  ),
                ),
              ],
              if (secret.isNotEmpty) ...[
                const SizedBox(height: 12),
                SelectableText(
                  AppCopy.text(
                    'text.manual_setup_key_value1_ae45860b',
                    arguments: {'value1': (secret).toString()},
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                AppCopy.text(
                  'text.this_setup_is_shown_only_now_do_not_send_it_thro_f91e9a06',
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppCopy.text('text.done_8dd31791')),
          ),
        ],
      ),
    );
  }

  void _showSafeError(BuildContext context, Object error) {
    final message = error is ApiException
        ? error.message
        : 'The administrator account request could not be completed. Try again.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InlineLoadError extends StatelessWidget {
  const _InlineLoadError({required this.onRetry, required this.message});

  final Future<void> Function() onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              AppCopy.text(
                'text.could_not_load_administrator_accounts_eeff5ab6',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
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
