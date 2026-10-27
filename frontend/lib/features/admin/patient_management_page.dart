import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/query/admin_query_keys.dart';
import 'package:frontend/core/widgets/admin/admin_access_scope.dart';
import 'package:frontend/core/widgets/admin/admin_dialogs.dart';
import 'package:frontend/core/widgets/admin/admin_scaffold.dart';
import 'package:frontend/core/widgets/common/api_error_state.dart';
import 'package:frontend/features/admin/admin_capabilities.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';

class PatientManagementPage extends StatefulWidget {
  const PatientManagementPage({super.key});

  @override
  State<PatientManagementPage> createState() => _PatientManagementPageState();
}

class _PatientManagementPageState extends State<PatientManagementPage> {
  final AdminRepository _repo = AppDependencies.adminRepository;
  final TextEditingController _searchController = TextEditingController();
  int _page = 1;
  String? _statusFilter;
  String? _doctorFilter;
  String? _doctorFilterLabel;
  List<Map<String, dynamic>> _availableDoctors = [];
  bool _availableDoctorsLoading = false;
  int _refreshKey = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final search = _searchController.text.trim();
    final canManage = AdminAccessScope.can(
      context,
      AdminCapabilities.tenantPatientsManage,
    );
    final canAssign = AdminAccessScope.can(
      context,
      AdminCapabilities.tenantPatientsAssign,
    );
    final canStatus = AdminAccessScope.can(
      context,
      AdminCapabilities.tenantAccountsStatusManage,
    );
    final canResetCredentials = AdminAccessScope.can(
      context,
      AdminCapabilities.tenantCredentialsReset,
    );

    return UseQuery<Map<String, dynamic>>(
      options: QueryOptions<Map<String, dynamic>>(
        queryKey: AdminQueryKeys.patients(
          page: _page,
          search: search,
          statusFilter: _statusFilter ?? '',
          doctorFilter: _doctorFilter ?? '',
          refreshKey: _refreshKey,
        ),
        queryFn: () => _repo.getAllPatients(
          page: _page,
          search: search.isNotEmpty ? search : null,
          accountStatus: _statusFilter,
          assignedDoctorId: _doctorFilter,
        ),
      ),
      builder: (context, query) {
        final dataMap = query.data ?? {};
        final patientsList = dataMap['patients'] as List? ?? [];
        final pagination = dataMap['pagination'] as Map<String, dynamic>? ?? {};
        final total = pagination['total'] as int? ?? patientsList.length;
        final pageSize = pagination['limit'] as int? ?? 20;
        final totalPages =
            pagination['pages'] as int? ?? (total / pageSize).ceil();
        final showPageScaffold = !AdminScaffold.usesShellAppBar(context);

        final addPatientFab = canManage
            ? FloatingActionButton.extended(
                onPressed: () =>
                    showAddPatientDialog(context, onSuccess: _refresh),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(AppCopy.text('text.add_patient_243c1f9d')),
              )
            : null;

        final content = Column(
          children: [
            if (!showPageScaffold)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppCopy.text('text.patient_management_8a38f5f1'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _showFilterSheet(context),
                          icon: const Icon(Icons.filter_list_rounded),
                          label: Text(AppCopy.text('text.filter_f4a9c097')),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(AppCopy.text('text.refresh_815aad4')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            // Search
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: AppCopy.text(
                    'text.search_patients_by_name_or_id_db17cd9b',
                  ),
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _page = 1);
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() => _page = 1),
              ),
            ),

            // Filter chips
            if (_statusFilter != null || _doctorFilter != null)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (_statusFilter != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InputChip(
                          label: Text(_statusFilter!),
                          onDeleted: () => setState(() {
                            _statusFilter = null;
                            _page = 1;
                          }),
                        ),
                      ),
                    if (_doctorFilter != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InputChip(
                          label: Text(
                            AppCopy.text(
                              'text.doctor_value1_2f9517c8',
                              arguments: {
                                'value1': (_doctorFilterLabel ?? _doctorFilter)
                                    .toString(),
                              },
                            ),
                          ),
                          onDeleted: () => setState(() {
                            _doctorFilter = null;
                            _doctorFilterLabel = null;
                            _page = 1;
                          }),
                        ),
                      ),
                    TextButton(
                      onPressed: () => setState(() {
                        _statusFilter = null;
                        _doctorFilter = null;
                        _doctorFilterLabel = null;
                        _page = 1;
                      }),
                      child: Text(AppCopy.text('text.clear_all_de7f94e5')),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // List
            Expanded(
              child: query.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : query.isError
                  ? ApiErrorState(error: query.error, onRetry: _refresh)
                  : patientsList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(AppCopy.text('text.no_patients_found_a637cb0')),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(bottom: canManage ? 80 : 16),
                      itemCount: patientsList.length,
                      itemBuilder: (context, index) {
                        final patient =
                            patientsList[index] as Map<String, dynamic>;
                        return _PatientListTile(
                          patient: patient,
                          onRefresh: _refresh,
                          canManage: canManage,
                          canAssign: canAssign,
                          canStatus: canStatus,
                          canResetCredentials: canResetCredentials,
                        );
                      },
                    ),
            ),

            // Pagination
            if (totalPages > 1)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _page > 1
                          ? () => setState(() => _page--)
                          : null,
                    ),
                    Text(
                      AppCopy.text(
                        'text.page_value1_of_value2_bd90d60a',
                        arguments: {
                          'value1': (_page).toString(),
                          'value2': (totalPages).toString(),
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _page < totalPages
                          ? () => setState(() => _page++)
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        );

        if (showPageScaffold) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                canManage
                    ? AppCopy.text('text.patient_management_8a38f5f1')
                    : AppCopy.text('text.patients_7364b4f7'),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.filter_list_rounded),
                  onPressed: () => _showFilterSheet(context),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _refresh,
                ),
              ],
            ),
            floatingActionButton: addPatientFab,
            body: content,
          );
        }

        if (addPatientFab == null) {
          return content;
        }

        return Stack(
          children: [
            Positioned.fill(child: content),
            Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(top: false, left: false, child: addPatientFab),
            ),
          ],
        );
      },
    );
  }

  void _showFilterSheet(BuildContext context) {
    String? status = _statusFilter;
    String? doctorId = _doctorFilter;
    String? doctorName = _doctorFilterLabel;
    List<Map<String, dynamic>> doctors = List.of(_availableDoctors);
    bool doctorsLoading = _availableDoctorsLoading || doctors.isEmpty;
    String? doctorLoadError;

    Future<void> loadDoctors(
      StateSetter setSheetState,
      BuildContext sheetContext,
    ) async {
      if (_availableDoctors.isNotEmpty || _availableDoctorsLoading) return;
      _availableDoctorsLoading = true;
      try {
        final response = await _repo.getAllDoctors(
          limit: 100,
          isActive: 'true',
        );
        final items = response['doctors'] as List? ?? [];
        doctors = items.cast<Map<String, dynamic>>();
        _availableDoctors = doctors;
        doctorLoadError = null;
      } catch (error) {
        doctorLoadError = error.toString();
      } finally {
        _availableDoctorsLoading = false;
        doctorsLoading = false;
        if (sheetContext.mounted) setSheetState(() {});
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (doctorsLoading) loadDoctors(setSheetState, ctx);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppCopy.text('text.filter_patients_36ac587'),
                  style: Theme.of(ctx).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                Text(
                  AppCopy.text('text.account_status_ebb2e11e'),
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: Text(AppCopy.text('text.all_75afe364')),
                      selected: status == null,
                      onSelected: (_) => setSheetState(() => status = null),
                    ),
                    FilterChip(
                      label: Text(AppCopy.text('text.active_1f89134f')),
                      selected: status == 'Active',
                      onSelected: (_) => setSheetState(() => status = 'Active'),
                    ),
                    FilterChip(
                      label: Text(AppCopy.text('text.discharged_dbe69549')),
                      selected: status == 'Discharged',
                      onSelected: (_) =>
                          setSheetState(() => status = 'Discharged'),
                    ),
                    FilterChip(
                      label: Text(AppCopy.text('text.deceased_1b212e3f')),
                      selected: status == 'Deceased',
                      onSelected: (_) =>
                          setSheetState(() => status = 'Deceased'),
                    ),
                    FilterChip(
                      label: Text(
                        AppCopy.text('text.assignment_conflict_8312dd32'),
                      ),
                      selected: status == 'AssignmentConflict',
                      onSelected: (_) =>
                          setSheetState(() => status = 'AssignmentConflict'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  AppCopy.text('text.assigned_doctor_ffb10bc4'),
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (doctorsLoading)
                  const LinearProgressIndicator()
                else if (doctorLoadError != null)
                  Text(
                    AppCopy.text(
                      'text.could_not_load_doctors_reopen_filters_to_retry_f6a0508e',
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: doctorId,
                    hint: Text(AppCopy.text('text.all_doctors_ad11cc44')),
                    decoration: InputDecoration(
                      labelText: AppCopy.text('text.doctor_91c5cb32'),
                    ),
                    items: doctors.map((doctor) {
                      final profile =
                          doctor['profile_id'] as Map<String, dynamic>? ?? {};
                      final id = (doctor['_id'] ?? doctor['id']).toString();
                      final name =
                          profile['name'] as String? ??
                          doctor['login_id'] as String? ??
                          'Unknown';
                      return DropdownMenuItem(value: id, child: Text(name));
                    }).toList(),
                    onChanged: (value) => setSheetState(() {
                      doctorId = value;
                      doctorName = doctors
                          .where(
                            (doctor) =>
                                (doctor['_id'] ?? doctor['id']).toString() ==
                                value,
                          )
                          .map(
                            (doctor) =>
                                (doctor['profile_id']
                                        as Map<String, dynamic>?)?['name']
                                    as String?,
                          )
                          .firstOrNull;
                    }),
                  ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _statusFilter = null;
                            _doctorFilter = null;
                            _doctorFilterLabel = null;
                            _page = 1;
                          });
                          Navigator.pop(ctx);
                        },
                        child: Text(AppCopy.text('text.reset_ac8a560')),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _statusFilter = status;
                            _doctorFilter = doctorId;
                            _doctorFilterLabel = doctorName;
                            _page = 1;
                          });
                          Navigator.pop(ctx);
                        },
                        child: Text(AppCopy.text('text.apply_ca77bbdb')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PatientListTile extends StatelessWidget {
  final Map<String, dynamic> patient;
  final VoidCallback onRefresh;
  final bool canManage;
  final bool canAssign;
  final bool canStatus;
  final bool canResetCredentials;

  const _PatientListTile({
    required this.patient,
    required this.onRefresh,
    required this.canManage,
    required this.canAssign,
    required this.canStatus,
    required this.canResetCredentials,
  });

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final theme = Theme.of(context);
    final profile =
        patient['profile_id'] as Map<String, dynamic>? ??
        patient['patient_profile'] as Map<String, dynamic>? ??
        {};
    final demographics = profile['demographics'] as Map<String, dynamic>? ?? {};
    final name =
        demographics['name'] as String? ??
        patient['login_id'] as String? ??
        'Unknown';
    final age = demographics['age'];
    final gender = demographics['gender'] as String? ?? '';
    final isActive = patient['is_active'] as bool? ?? true;
    final accountStatus = profile['account_status'] as String? ?? 'Active';
    final id =
        patient['_id'] as String? ??
        patient['id'] as String? ??
        patient['user_id'] as String? ??
        '';
    final opNum = patient['login_id'] as String? ?? '';
    final assignedDoctorRef =
        profile['assigned_doctor_id'] ?? patient['assigned_doctor_id'];
    final currentDoctorId = assignedDoctorRef is Map
        ? (assignedDoctorRef['_id'] ?? assignedDoctorRef['id'])?.toString() ??
              ''
        : assignedDoctorRef?.toString() ?? '';
    final assignedDoctorProfile = assignedDoctorRef is Map
        ? assignedDoctorRef['profile_id'] as Map<String, dynamic>?
        : null;
    final assignedDoctorName =
        patient['assigned_doctor_name'] as String? ??
        assignedDoctorProfile?['name'] as String? ??
        (currentDoctorId.isEmpty ? 'Unassigned' : 'Doctor unavailable');
    final details = [
      if (age != null) 'Age: $age',
      if (gender.isNotEmpty) gender,
    ].join(' | ');
    final hasActions =
        canManage || canAssign || canStatus || canResetCredentials;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (hasActions)
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (action) => _handleAction(
                            context,
                            action,
                            id,
                            name,
                            opNum,
                            demographics,
                            isActive,
                            currentDoctorId,
                            accountStatus,
                          ),
                          itemBuilder: (_) => [
                            if (canManage)
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit_rounded, size: 20),
                                  title: Text(
                                    AppCopy.text('text.edit_c2c76cb1'),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            if (canAssign && accountStatus != 'Deceased')
                              PopupMenuItem(
                                value: 'reassign',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 20,
                                  ),
                                  title: Text(
                                    accountStatus == 'AssignmentConflict'
                                        ? AppCopy.text(
                                            'text.resolve_assignment_conflict_ddc90d56',
                                          )
                                        : AppCopy.text(
                                            'text.reassign_doctor_55c53170',
                                          ),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            if (canResetCredentials)
                              PopupMenuItem(
                                value: 'password',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.lock_reset_rounded,
                                    size: 20,
                                  ),
                                  title: Text(
                                    AppCopy.text(
                                      'text.reset_password_e61eb009',
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            if (canStatus && accountStatus != 'Deceased')
                              PopupMenuItem(
                                value: 'status',
                                child: ListTile(
                                  leading: Icon(
                                    isActive
                                        ? Icons.block_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 20,
                                    color: isActive ? Colors.red : Colors.green,
                                  ),
                                  title: Text(
                                    isActive
                                        ? AppCopy.text(
                                            'text.deactivate_7fcfb5f3',
                                          )
                                        : AppCopy.text(
                                            'text.activate_3b8f0190',
                                          ),
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (opNum.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            AppCopy.text(
                              'text.op_value1_38c57f2b',
                              arguments: {'value1': (opNum).toString()},
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AppCopy.text(
                            'text.login_value1_31160fee',
                            arguments: {
                              'value1': (isActive ? 'Active' : 'Inactive')
                                  .toString(),
                            },
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isActive
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accountStatus == 'AssignmentConflict'
                              ? theme.colorScheme.errorContainer
                              : theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AppCopy.text(
                            'text.clinical_value1_c59500da',
                            arguments: {'value1': (accountStatus).toString()},
                          ),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppCopy.text(
                      'text.assigned_doctor_value1_59b7cd96',
                      arguments: {'value1': (assignedDoctorName).toString()},
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (accountStatus == 'AssignmentConflict') ...[
                    const SizedBox(height: 4),
                    Text(
                      AppCopy.text(
                        'text.assignment_repair_is_required_before_clinical_ac_22735be2',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  if (accountStatus == 'Deceased') ...[
                    const SizedBox(height: 4),
                    Text(
                      AppCopy.text(
                        'text.deceased_patient_records_cannot_be_reactivated_o_8eb5cb8b',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      details,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(
    BuildContext context,
    String action,
    String id,
    String name,
    String opNum,
    Map<String, dynamic> demographics,
    bool isActive,
    String currentDoctorId,
    String accountStatus,
  ) {
    switch (action) {
      case 'edit':
        showEditPatientDialog(
          context,
          patientId: id,
          currentData: demographics,
          onSuccess: onRefresh,
        );
        break;
      case 'password':
        showResetPasswordDialog(
          context,
          userId: id,
          userName: name,
          onReset: (password) async {
            await AppDependencies.adminRepository.resetPatientCredentials(
              id,
              newPassword: password,
            );
          },
          onSuccess: onRefresh,
        );
        break;
      case 'reassign':
        showReassignPatientDialog(
          context,
          patientOpNum: opNum,
          currentDoctorId: currentDoctorId,
          resolvingConflict: accountStatus == 'AssignmentConflict',
          onSuccess: onRefresh,
        );
        break;
      case 'status':
        if (accountStatus == 'AssignmentConflict' && !isActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppCopy.text(
                  'text.resolve_the_assignment_conflict_before_activatin_da6f6d15',
                ),
              ),
            ),
          );
          return;
        }
        showStatusToggleDialog(
          context,
          isActive: isActive,
          userName: name,
          userType: 'Patient',
          onConfirm: () async {
            await AppDependencies.adminRepository.updatePatientStatus(
              id,
              isActive: !isActive,
              accountStatus: !isActive ? 'Active' : 'Discharged',
            );
          },
          onSuccess: onRefresh,
        );
        break;
    }
  }
}
