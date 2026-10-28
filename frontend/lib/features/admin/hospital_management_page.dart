import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/query/admin_query_keys.dart';
import 'package:frontend/core/widgets/admin/admin_access_gate.dart';
import 'package:frontend/core/widgets/admin/admin_access_scope.dart';
import 'package:frontend/core/widgets/admin/admin_action_confirmation.dart';
import 'package:frontend/features/admin/admin_capabilities.dart';
import 'package:frontend/features/admin/admin_console_components.dart';
import 'package:frontend/features/admin/models/admin_access_model.dart';

class HospitalManagementPage extends StatefulWidget {
  const HospitalManagementPage({super.key});

  @override
  State<HospitalManagementPage> createState() => _HospitalManagementPageState();
}

class _HospitalManagementPageState extends State<HospitalManagementPage> {
  final _repo = AppDependencies.adminRepository;
  final _search = TextEditingController();
  int _refreshKey = 0;
  String? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return AdminAccessGate(
      anyCapabilities: const [AdminCapabilities.platformHospitalsRead],
      roles: const {AdminRole.appAdmin, AdminRole.auditor},
      scope: AdminScope.global,
      builder: (context) {
        final canManage = AdminAccessScope.can(
          context,
          AdminCapabilities.platformHospitalsManage,
        );
        return UseQuery<Map<String, dynamic>>(
          options: QueryOptions<Map<String, dynamic>>(
            queryKey: AdminQueryKeys.hospitals(
              refreshKey: _refreshKey,
              status: _status,
              search: _search.text.trim(),
            ),
            queryFn: () => _repo.getHospitals(
              search: _search.text.trim(),
              status: _status,
            ),
          ),
          builder: (context, query) {
            final hospitals = query.data?['hospitals'] as List? ?? const [];
            final content = AdminListShell(
              title: AppCopy.text('text.hospitals_64b409e0'),
              subtitle: canManage
                  ? AppCopy.text(
                      'text.manage_hospital_tenants_status_and_platform_acce_c5f8f187',
                    )
                  : AppCopy.text(
                      'text.read_only_hospital_directory_and_operational_met_f8f95517',
                    ),
              searchController: _search,
              searchHint: AppCopy.text('text.search_hospitals_7c05c1a6'),
              onSearch: _refresh,
              actions: [
                DropdownButton<String?>(
                  value: _status,
                  hint: Text(AppCopy.text('text.all_status_a9856756')),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(AppCopy.text('text.all_status_a9856756')),
                    ),
                    DropdownMenuItem(
                      value: 'active',
                      child: Text(AppCopy.text('text.active_1f89134f')),
                    ),
                    DropdownMenuItem(
                      value: 'suspended',
                      child: Text(AppCopy.text('text.suspended_33478642')),
                    ),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text(AppCopy.text('text.inactive_901aca78')),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _status = value;
                    _refreshKey++;
                  }),
                ),
                if (canManage)
                  FilledButton.icon(
                    onPressed: () => _showHospitalDialog(context),
                    icon: const Icon(Icons.add_business_rounded),
                    label: Text(AppCopy.text('text.add_9dc3aa14')),
                  ),
              ],
              child: AdminQueryBody<Map<String, dynamic>>(
                query: query,
                emptyIcon: Icons.local_hospital_outlined,
                emptyText: 'No hospitals found',
                isEmpty: hospitals.isEmpty,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: hospitals.length,
                  itemBuilder: (context, index) {
                    final h = hospitals[index] as Map<String, dynamic>;
                    final id = (h['id'] ?? h['_id']).toString();
                    final name = (h['name'] ?? 'Hospital').toString();
                    final status = (h['status'] ?? 'inactive').toString();
                    return AdminRecordCard(
                      icon: Icons.local_hospital_rounded,
                      title: name,
                      badge: status,
                      details: [
                        AdminDetail(Icons.tag_rounded, id),
                        AdminDetail(
                          Icons.place_rounded,
                          '${h['location'] ?? '--'}',
                        ),
                        AdminDetail(
                          Icons.mail_outline_rounded,
                          '${h['admin'] ?? '--'}',
                        ),
                        AdminDetail(
                          Icons.medical_services_outlined,
                          '${h['doctors'] ?? 0} doctors',
                        ),
                        AdminDetail(
                          Icons.people_outline,
                          '${h['patients'] ?? 0} patients',
                        ),
                      ],
                      menu: canManage
                          ? [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(
                                  AppCopy.text('text.edit_hospital_593abbc9'),
                                ),
                                onTap: () => Future.microtask(() {
                                  if (mounted) {
                                    _showHospitalDialog(
                                      this.context,
                                      hospital: h,
                                    );
                                  }
                                }),
                              ),
                              PopupMenuItem(
                                value: 'status',
                                child: Text(
                                  status == 'active'
                                      ? AppCopy.text('text.suspend_e196ab03')
                                      : AppCopy.text('text.activate_3b8f0190'),
                                ),
                                onTap: () => Future.microtask(
                                  () => _confirmHospitalStatus(
                                    name,
                                    id,
                                    status == 'active' ? 'suspended' : 'active',
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  AppCopy.text('text.deactivate_7fcfb5f3'),
                                ),
                                onTap: () => Future.microtask(
                                  () => _confirmHospitalDeactivation(name, id),
                                ),
                              ),
                            ]
                          : const [],
                    );
                  },
                ),
              ),
            );
            return adminPageScaffold(context, 'Hospitals', content);
          },
        );
      },
    );
  }

  Future<void> _confirmHospitalStatus(
    String hospitalName,
    String id,
    String status,
  ) async {
    final action = status == 'suspended' ? 'Suspend' : 'Activate';
    final confirmed = await showAdminActionConfirmation(
      context,
      title: "${(action).toString()} ${(hospitalName).toString()}?",
      message: status == 'suspended'
          ? AppCopy.text(
              'text.staff_and_patients_will_lose_hospital_access_ind_e411b485',
            )
          : AppCopy.text(
              'text.this_restores_hospital_access_deactivated_user_a_f0b91bab',
            ),
      confirmLabel: action,
    );
    if (!confirmed || !mounted) return;
    await _runAction(
      () => _repo.updateHospitalStatus(id, status),
      status == 'suspended'
          ? '$hospitalName suspended successfully.'
          : '$hospitalName activated. Deactivated user accounts remain inactive until reactivated.',
    );
  }

  Future<void> _confirmHospitalDeactivation(
    String hospitalName,
    String id,
  ) async {
    final confirmed = await showAdminActionConfirmation(
      context,
      title: AppCopy.text(
        'text.deactivate_value1_163142e6',
        arguments: {'value1': (hospitalName).toString()},
      ),
      message: AppCopy.text(
        'text.this_removes_platform_access_for_the_hospital_yo_45557fe9',
      ),
      confirmLabel: AppCopy.text('text.deactivate_7fcfb5f3'),
    );
    if (!confirmed || !mounted) return;
    await _runAction(
      () => _repo.deleteHospital(id),
      '$hospitalName deactivated successfully.',
    );
  }

  Future<void> _runAction(
    Future<dynamic> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (mounted) showAdminError(context, e);
    }
  }

  Future<void> _showHospitalDialog(
    BuildContext context, {
    Map<String, dynamic>? hospital,
  }) async {
    final name = TextEditingController(
      text: (hospital?['name'] ?? '').toString(),
    );
    final location = TextEditingController(
      text: (hospital?['location'] ?? '').toString(),
    );
    final admin = TextEditingController(
      text: (hospital?['admin'] ?? '').toString(),
    );
    var status = '${hospital?['status'] ?? 'active'}';
    final id = '${hospital?['id'] ?? hospital?['_id'] ?? ''}';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          hospital == null
              ? AppCopy.text('text.add_hospital_460b663a')
              : AppCopy.text('text.edit_hospital_9231c0e9'),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: AppCopy.text('text.hospital_name_6920c662'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: location,
                decoration: InputDecoration(
                  labelText: AppCopy.text('text.location_5bc08dc6'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: admin,
                decoration: InputDecoration(
                  labelText: AppCopy.text('text.admin_email_dd8d07b4'),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: InputDecoration(
                  labelText: AppCopy.text('text.status_5ef20f'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'active',
                    child: Text(AppCopy.text('text.active_1f89134f')),
                  ),
                  DropdownMenuItem(
                    value: 'suspended',
                    child: Text(AppCopy.text('text.suspended_33478642')),
                  ),
                ],
                onChanged: (value) => status = value ?? status,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppCopy.text('text.cancel_35afca3b')),
          ),
          FilledButton(
            onPressed: () async {
              final data = {
                'name': name.text.trim(),
                'location': location.text.trim(),
                'admin_email': admin.text.trim(),
                'status': status,
              };
              try {
                if (hospital == null) {
                  await _repo.createHospital(data);
                } else {
                  await _repo.updateHospital(id, data);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) _refresh();
              } catch (e) {
                if (dialogContext.mounted) showAdminError(dialogContext, e);
              }
            },
            child: Text(AppCopy.text('text.save_4d2d5d68')),
          ),
        ],
      ),
    );
    name.dispose();
    location.dispose();
    admin.dispose();
  }
}
