import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/utils/phone_utils.dart';
import 'package:frontend/core/widgets/admin/admin_access_scope.dart';
import 'package:frontend/core/widgets/admin/admin_mutation_dialog.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';
import 'package:frontend/features/admin/models/admin_access_model.dart';

/// Reusable dialog helpers for admin CRUD operations.
/// These use the [AdminRepository] directly via [AppDependencies] instead of
/// Riverpod providers (matching the target project conventions).

final AdminRepository _repo = AppDependencies.adminRepository;
final RegExp _strongPasswordRegex = RegExp(
  r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$',
);

String? _validateStrongPassword(String? value) {
  if (value == null || value.isEmpty) return 'Required';
  if (!_strongPasswordRegex.hasMatch(value)) {
    return AppCopy.text(
      'text.use_8_chars_with_upper_lower_number_special_66398b1a',
    );
  }
  return null;
}

void _disposeControllers(Iterable<TextEditingController> controllers) {
  for (final controller in controllers) {
    controller.dispose();
  }
}

String _errorMessage(Object error) {
  if (error is ApiException) return error.message;
  return error.toString();
}

/// Tenant hospital admins are bound to one hospital; app admins pick from the catalog.
({bool isTenant, String? hospitalId, String hospitalLabel}) _hospitalBinding(
  BuildContext context,
) {
  final access = AdminAccessScope.accessOf(context);
  if (access != null &&
      access.scope == AdminScope.tenant &&
      access.hospital != null) {
    final hospital = access.hospital!;
    final label = [
      if (hospital.name != null && hospital.name!.trim().isNotEmpty)
        hospital.name!.trim(),
      hospital.code,
    ].join(' · ');
    return (isTenant: true, hospitalId: hospital.id, hospitalLabel: label);
  }
  return (isTenant: false, hospitalId: null, hospitalLabel: '');
}

// =============================================================================
// DOCTOR DIALOGS
// =============================================================================

String? _resolveHospitalId(dynamic hospitalRef) {
  if (hospitalRef is Map<String, dynamic>) {
    return (hospitalRef['_id'] ?? hospitalRef['id'])?.toString();
  }
  if (hospitalRef != null) {
    return hospitalRef.toString();
  }
  return null;
}

Future<bool> showAddDoctorDialog(
  BuildContext context, {
  VoidCallback? onSuccess,
}) async {
  final formKey = GlobalKey<FormState>();
  final loginId = TextEditingController();
  final name = TextEditingController();
  final department = TextEditingController();
  final contact = TextEditingController();
  final binding = _hospitalBinding(context);
  bool loading = false;
  String? selectedHospitalId = binding.hospitalId;
  List<Map<String, dynamic>> hospitalList = [];
  bool hospitalsLoading = !binding.isTenant;
  bool hospitalsRequested = binding.isTenant;
  String? hospitalsError;
  String? formError;

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        if (!hospitalsRequested) {
          hospitalsRequested = true;
          _repo
              .getHospitals(status: 'active')
              .then((response) {
                final items = response['hospitals'] as List? ?? [];
                if (ctx.mounted) {
                  setState(() {
                    hospitalList = items.cast<Map<String, dynamic>>();
                    hospitalsLoading = false;
                    // Prefer a single catalog entry when only one hospital is returned.
                    if (selectedHospitalId == null &&
                        hospitalList.length == 1) {
                      final only = hospitalList.first;
                      selectedHospitalId = (only['_id'] ?? only['id'])
                          ?.toString();
                    }
                  });
                }
              })
              .catchError((e) {
                if (ctx.mounted) {
                  setState(() {
                    hospitalsError = _errorMessage(e);
                    hospitalsLoading = false;
                  });
                }
              });
        }

        return AdminMutationDialog(
          busy: loading,
          child: AlertDialog(
            title: Text(AppCopy.text('text.register_new_doctor_a2302a2d')),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: loginId,
                      decoration: InputDecoration(
                        labelText: AppCopy.text('text.login_id_319267cb'),
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      enabled: !loading,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: AppCopy.text('text.full_name_fe2b40f'),
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                      enabled: !loading,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: department,
                      decoration: InputDecoration(
                        labelText: AppCopy.text('text.department_90770c67'),
                        hintText: AppCopy.text('text.e_g_cardiology_a1df07c0'),
                        prefixIcon: Icon(Icons.local_hospital_rounded),
                      ),
                      enabled: !loading,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contact,
                      decoration: InputDecoration(
                        labelText: AppCopy.text('text.contact_number_b7360224'),
                        hintText: AppCopy.text(
                          'text.10_digit_indian_number_e2356744',
                        ),
                        helperText: AppCopy.text(
                          'text.91_is_added_automatically_10a7eeeb',
                        ),
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                      keyboardType: TextInputType.phone,
                      enabled: !loading,
                      validator: (v) => PhoneUtils.validate(
                        v,
                        label: AppCopy.text('text.contact_73ac94c3'),
                        required: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (binding.isTenant)
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: AppCopy.text('text.hospital_30217ad3'),
                          prefixIcon: Icon(Icons.local_hospital_outlined),
                          helperText: AppCopy.text(
                            'text.doctors_are_registered_under_your_assigned_hospi_2d6a537c',
                          ),
                        ),
                        child: Text(binding.hospitalLabel),
                      )
                    else
                      DropdownButtonFormField<String?>(
                        initialValue: selectedHospitalId,
                        decoration: InputDecoration(
                          labelText: AppCopy.text('text.hospital_30217ad3'),
                          prefixIcon: Icon(Icons.local_hospital_outlined),
                          hintText: AppCopy.text(
                            'text.select_hospital_3804d8c5',
                          ),
                        ),
                        isExpanded: true,
                        items: [
                          ...hospitalList.map((hospital) {
                            final id =
                                (hospital['_id'] ?? hospital['id'])
                                    ?.toString() ??
                                '';
                            final label =
                                hospital['name'] as String? ??
                                hospital['code'] as String? ??
                                'Hospital';
                            return DropdownMenuItem<String?>(
                              value: id.isNotEmpty ? id : null,
                              child: Text(label),
                            );
                          }),
                        ],
                        onChanged: hospitalsLoading
                            ? null
                            : (value) =>
                                  setState(() => selectedHospitalId = value),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Hospital is required'
                            : null,
                        hint: hospitalsLoading
                            ? Text(
                                AppCopy.text('text.loading_hospitals_efa19956'),
                              )
                            : Text(
                                AppCopy.text('text.select_hospital_3804d8c5'),
                              ),
                      ),
                    if (hospitalsError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          hospitalsError!,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      AppCopy.text(
                        'text.a_temporary_password_is_generated_after_registra_e9ee3f90',
                      ),
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (formError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          formError!,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(ctx, false),
                child: Text(AppCopy.text('text.cancel_35afca3b')),
              ),
              FilledButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final hospitalId = binding.isTenant
                            ? binding.hospitalId
                            : selectedHospitalId;
                        if (hospitalId == null || hospitalId.isEmpty) {
                          setState(() {
                            formError =
                                'Hospital is required to register a doctor.';
                          });
                          return;
                        }
                        setState(() {
                          loading = true;
                          formError = null;
                        });
                        try {
                          final contactNumber = PhoneUtils.formatForApi(
                            contact.text,
                          );
                          if (contactNumber == null) {
                            setState(() {
                              loading = false;
                              formError =
                                  'Enter a valid 10-digit contact number.';
                            });
                            return;
                          }
                          // Do not send password — backend generates a temporary one
                          // and createDoctorSchema rejects unknown fields (strict).
                          final created = await _repo.createDoctor({
                            'login_id': loginId.text.trim(),
                            'name': name.text.trim(),
                            'department': department.text.trim().isNotEmpty
                                ? department.text.trim()
                                : 'General',
                            'contact_number': contactNumber,
                            'hospital_id': hospitalId,
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx, created);
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setState(() {
                              loading = false;
                              formError = _errorMessage(e);
                            });
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(formError!),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppCopy.text('text.register_2739c9e0')),
              ),
            ],
          ),
        );
      },
    ),
  );

  _disposeControllers([loginId, name, department, contact]);

  if (result != null && context.mounted) {
    final tempPassword = result['temporary_password']?.toString();
    await showAdminCredentialResult(
      context,
      title: AppCopy.text('text.doctor_registered_6c7554de'),
      successMessage: tempPassword != null && tempPassword.isNotEmpty
          ? AppCopy.text(
              'text.doctor_registered_share_this_one_time_password_s_5215bec6',
            )
          : AppCopy.text('text.doctor_registered_successfully_9e830feb'),
      temporaryPassword: tempPassword,
    );
    onSuccess?.call();
    return true;
  }
  return false;
}

Future<bool> showEditDoctorDialog(
  BuildContext context, {
  required String doctorId,
  required Map<String, dynamic> currentData,
  VoidCallback? onSuccess,
}) async {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(
    text: currentData['name'] as String? ?? '',
  );
  final department = TextEditingController(
    text: currentData['department'] as String? ?? '',
  );
  final contact = TextEditingController(
    text: PhoneUtils.toLocalDigits(
      currentData['contact_number'] as String? ?? '',
    ),
  );
  final binding = _hospitalBinding(context);
  bool loading = false;
  String? selectedHospitalId =
      binding.hospitalId ?? _resolveHospitalId(currentData['hospital_id']);
  List<Map<String, dynamic>> hospitalList = [];
  bool hospitalsLoading = !binding.isTenant;
  bool hospitalsRequested = binding.isTenant;
  String? hospitalsError;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        if (!hospitalsRequested) {
          hospitalsRequested = true;
          _repo
              .getHospitals(status: 'active')
              .then((response) {
                final items = response['hospitals'] as List? ?? [];
                if (ctx.mounted) {
                  setState(() {
                    hospitalList = items.cast<Map<String, dynamic>>();
                    hospitalsLoading = false;
                  });
                }
              })
              .catchError((e) {
                if (ctx.mounted) {
                  setState(() {
                    hospitalsError = _errorMessage(e);
                    hospitalsLoading = false;
                  });
                }
              });
        }

        return AlertDialog(
          title: Text(AppCopy.text('text.edit_doctor_31103520')),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: AppCopy.text('text.full_name_fe2b40f'),
                    ),
                    enabled: !loading,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: department,
                    decoration: InputDecoration(
                      labelText: AppCopy.text('text.department_90770c67'),
                    ),
                    enabled: !loading,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: contact,
                    decoration: InputDecoration(
                      labelText: AppCopy.text('text.contact_number_b7360224'),
                      hintText: AppCopy.text(
                        'text.10_digit_indian_number_e2356744',
                      ),
                      helperText: AppCopy.text(
                        'text.91_is_added_automatically_10a7eeeb',
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    enabled: !loading,
                    validator: (v) => PhoneUtils.validate(
                      v,
                      label: AppCopy.text('text.contact_73ac94c3'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (binding.isTenant)
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: AppCopy.text('text.hospital_30217ad3'),
                        prefixIcon: Icon(Icons.local_hospital_outlined),
                        helperText: AppCopy.text(
                          'text.hospital_assignment_is_fixed_for_your_tenant_b5255042',
                        ),
                      ),
                      child: Text(binding.hospitalLabel),
                    )
                  else
                    DropdownButtonFormField<String?>(
                      initialValue: selectedHospitalId,
                      decoration: InputDecoration(
                        labelText: AppCopy.text('text.hospital_30217ad3'),
                        prefixIcon: Icon(Icons.local_hospital_outlined),
                        hintText: AppCopy.text('text.select_hospital_3804d8c5'),
                      ),
                      isExpanded: true,
                      items: [
                        ...hospitalList.map((hospital) {
                          final id =
                              (hospital['_id'] ?? hospital['id'])?.toString() ??
                              '';
                          final label =
                              hospital['name'] as String? ??
                              hospital['code'] as String? ??
                              'Hospital';
                          return DropdownMenuItem<String?>(
                            value: id.isNotEmpty ? id : null,
                            child: Text(label),
                          );
                        }),
                      ],
                      onChanged: hospitalsLoading
                          ? null
                          : (value) =>
                                setState(() => selectedHospitalId = value),
                      hint: hospitalsLoading
                          ? Text(
                              AppCopy.text('text.loading_hospitals_efa19956'),
                            )
                          : Text(AppCopy.text('text.select_hospital_3804d8c5')),
                    ),
                  if (hospitalsError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        hospitalsError!,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx, false),
              child: Text(AppCopy.text('text.cancel_35afca3b')),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => loading = true);
                      try {
                        final contactNumber = PhoneUtils.formatForApi(
                          contact.text,
                        );
                        final hospitalId = binding.isTenant
                            ? binding.hospitalId
                            : selectedHospitalId;
                        await _repo.updateDoctor(doctorId, {
                          'name': name.text.trim(),
                          'department': department.text.trim(),
                          if (contactNumber != null)
                            'contact_number': contactNumber,
                          if (hospitalId != null && hospitalId.isNotEmpty)
                            'hospital_id': hospitalId,
                        });
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(_errorMessage(e)),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setState(() => loading = false);
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppCopy.text('text.update_6e230e94')),
            ),
          ],
        );
      },
    ),
  );

  _disposeControllers([name, department, contact]);

  if (result == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppCopy.text('text.doctor_updated_successfully_b3a03bea'),
        ),
        backgroundColor: Colors.green,
      ),
    );
    onSuccess?.call();
  }
  return result ?? false;
}

// =============================================================================
// PATIENT DIALOGS
// =============================================================================

Future<bool> showAddPatientDialog(
  BuildContext context, {
  List<Map<String, dynamic>> doctors = const [],
  VoidCallback? onSuccess,
}) async {
  final formKey = GlobalKey<FormState>();
  final loginId = TextEditingController();
  final name = TextEditingController();
  final age = TextEditingController();
  final phone = TextEditingController();
  String? selectedDoctorId;
  String? selectedGender;

  // Auto-fetch doctors if none provided
  List<Map<String, dynamic>> doctorList = List.from(doctors);
  bool doctorsLoading = doctorList.isEmpty;
  bool doctorsRequested = !doctorsLoading;
  String? doctorsError;
  bool loading = false;
  final doctorSearch = TextEditingController();
  var doctorSearchSequence = 0;
  var doctorHasMore = false;
  var doctorPage = 1;

  Future<void> loadDoctors(
    StateSetter setState,
    BuildContext ctx, {
    bool reset = false,
  }) async {
    final sequence = ++doctorSearchSequence;
    final requestedPage = reset ? 1 : doctorPage + 1;
    await Future<void>.delayed(Duration.zero);
    if (!ctx.mounted || sequence != doctorSearchSequence) return;
    setState(() {
      doctorsLoading = true;
      doctorsError = null;
    });
    try {
      final response = await _repo.getDoctorAssignmentOptions(
        page: requestedPage,
        search: doctorSearch.text,
      );
      if (!ctx.mounted || sequence != doctorSearchSequence) return;
      final items = (response['doctors'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
      setState(() {
        doctorList = reset ? items : [...doctorList, ...items];
        doctorPage = requestedPage;
        doctorHasMore = pagination['hasNext'] == true || items.length == 20;
        doctorsLoading = false;
      });
    } catch (e) {
      if (!ctx.mounted || sequence != doctorSearchSequence) return;
      setState(() {
        doctorsError = _errorMessage(e);
        doctorsLoading = false;
      });
    }
  }

  final result = await showDialog<Object?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        // Fetch doctors on first build if list is empty
        if (!doctorsRequested) {
          doctorsRequested = true;
          loadDoctors(setState, ctx, reset: true);
        }

        return AdminMutationDialog(
          busy: loading,
          child: AlertDialog(
            title: Text(AppCopy.text('text.onboard_new_patient_578f2f53')),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: loginId,
                      decoration: InputDecoration(
                        labelText: AppCopy.text('text.login_id_319267cb'),
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      enabled: !loading,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: AppCopy.text('text.full_name_fe2b40f'),
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                      enabled: !loading,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    if (doctorsLoading)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text(AppCopy.text('text.loading_doctors_ca2e80f')),
                          ],
                        ),
                      )
                    else if (doctorsError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          doctorsError!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      )
                    else ...[
                      TextField(
                        controller: doctorSearch,
                        decoration: InputDecoration(
                          labelText: AppCopy.text(
                            'text.search_doctors_992bbfa1',
                          ),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: doctorSearch.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    doctorSearch.clear();
                                    loadDoctors(setState, ctx, reset: true);
                                  },
                                ),
                        ),
                        onChanged: (_) =>
                            loadDoctors(setState, ctx, reset: true),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: AppCopy.text(
                            'text.assigned_doctor_2c77d0e4',
                          ),
                          prefixIcon: Icon(Icons.medical_services_rounded),
                        ),
                        items: doctorList.map((d) {
                          final dName =
                              d['name'] as String? ??
                              d['login_id'] as String? ??
                              'Unknown';
                          return DropdownMenuItem(
                            value: d['_id'] as String? ?? d['id'] as String?,
                            child: Text(dName),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => selectedDoctorId = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      if (doctorHasMore)
                        TextButton.icon(
                          onPressed: doctorsLoading
                              ? null
                              : () => loadDoctors(setState, ctx),
                          icon: const Icon(Icons.expand_more),
                          label: Text(
                            AppCopy.text('text.load_more_doctors_13d0685a'),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: age,
                            decoration: InputDecoration(
                              labelText: AppCopy.text('text.age_8ecbe13c'),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: AppCopy.text('text.gender_a72c0ba0'),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'Male',
                                child: Text(AppCopy.text('text.male_487d36f0')),
                              ),
                              DropdownMenuItem(
                                value: 'Female',
                                child: Text(
                                  AppCopy.text('text.female_d8a26cb9'),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Other',
                                child: Text(
                                  AppCopy.text('text.other_6e38ff95'),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => selectedGender = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phone,
                      decoration: InputDecoration(
                        labelText: AppCopy.text('text.phone_number_f25088d8'),
                        hintText: AppCopy.text(
                          'text.10_digit_indian_number_e2356744',
                        ),
                        helperText: AppCopy.text(
                          'text.91_is_added_automatically_10a7eeeb',
                        ),
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                      keyboardType: TextInputType.phone,
                      enabled: !loading,
                      validator: (v) => PhoneUtils.validate(
                        v,
                        label: AppCopy.text('text.phone_4930944f'),
                        required: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppCopy.text(
                        'text.a_temporary_password_is_generated_after_onboardi_60f4856a',
                      ),
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(ctx, false),
                child: Text(AppCopy.text('text.cancel_35afca3b')),
              ),
              FilledButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate() ||
                            selectedDoctorId == null) {
                          return;
                        }
                        setState(() => loading = true);
                        try {
                          final phoneNumber = PhoneUtils.formatForApi(
                            phone.text,
                          );
                          if (phoneNumber == null) {
                            setState(() => loading = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppCopy.text(
                                    'text.enter_a_valid_phone_number_30528039',
                                  ),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          // Backend rejects unknown password field (strict body).
                          final created = await _repo.createPatient({
                            'login_id': loginId.text.trim(),
                            'assigned_doctor_id': selectedDoctorId,
                            'demographics': {
                              'name': name.text.trim(),
                              if (age.text.isNotEmpty)
                                'age': int.tryParse(age.text),
                              if (selectedGender != null)
                                'gender': selectedGender,
                              'phone': phoneNumber,
                            },
                          });
                          if (ctx.mounted) Navigator.pop(ctx, created);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(_errorMessage(e)),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setState(() => loading = false);
                          }
                        }
                      },
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppCopy.text('text.onboard_3c7b7b90')),
              ),
            ],
          ),
        );
      },
    ),
  );

  _disposeControllers([loginId, name, age, phone]);

  if (result is Map<String, dynamic> && context.mounted) {
    final tempPassword = result['temporary_password']?.toString();
    await showAdminCredentialResult(
      context,
      title: AppCopy.text('text.patient_onboarded_85253f80'),
      successMessage: tempPassword != null && tempPassword.isNotEmpty
          ? AppCopy.text(
              'text.patient_onboarded_share_this_one_time_password_s_69fd5c58',
            )
          : AppCopy.text('text.patient_onboarded_successfully_7fbf4be1'),
      temporaryPassword: tempPassword,
    );
    onSuccess?.call();
    doctorSearch.dispose();
    return true;
  }
  doctorSearch.dispose();
  return false;
}

Future<bool> showEditPatientDialog(
  BuildContext context, {
  required String patientId,
  required Map<String, dynamic> currentData,
  VoidCallback? onSuccess,
}) async {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(
    text: currentData['name'] as String? ?? '',
  );
  final age = TextEditingController(
    text: currentData['age'] != null ? (currentData['age']).toString() : '',
  );
  final phone = TextEditingController(
    text: PhoneUtils.toLocalDigits(currentData['phone'] as String? ?? ''),
  );
  String? selectedGender = currentData['gender'] as String?;
  bool loading = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: Text(AppCopy.text('text.edit_patient_details_b99cb4da')),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: AppCopy.text('text.full_name_fe2b40f'),
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                    enabled: !loading,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: age,
                          decoration: InputDecoration(
                            labelText: AppCopy.text('text.age_8ecbe13c'),
                          ),
                          keyboardType: TextInputType.number,
                          enabled: !loading,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              [
                                'Male',
                                'Female',
                                'Other',
                              ].contains(selectedGender)
                              ? selectedGender
                              : null,
                          decoration: InputDecoration(
                            labelText: AppCopy.text('text.gender_a72c0ba0'),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'Male',
                              child: Text(AppCopy.text('text.male_487d36f0')),
                            ),
                            DropdownMenuItem(
                              value: 'Female',
                              child: Text(AppCopy.text('text.female_d8a26cb9')),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text(AppCopy.text('text.other_6e38ff95')),
                            ),
                          ],
                          onChanged: loading
                              ? null
                              : (v) => setState(() => selectedGender = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phone,
                    decoration: InputDecoration(
                      labelText: AppCopy.text('text.phone_number_f25088d8'),
                      hintText: AppCopy.text(
                        'text.10_digit_indian_number_e2356744',
                      ),
                      helperText: AppCopy.text(
                        'text.91_is_added_automatically_10a7eeeb',
                      ),
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                    keyboardType: TextInputType.phone,
                    enabled: !loading,
                    validator: (v) => PhoneUtils.validate(
                      v,
                      label: AppCopy.text('text.phone_4930944f'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx, false),
              child: Text(AppCopy.text('text.cancel_35afca3b')),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => loading = true);
                      try {
                        final phoneNumber = PhoneUtils.formatForApi(phone.text);
                        await _repo.updatePatient(patientId, {
                          'demographics': {
                            'name': name.text.trim(),
                            if (age.text.trim().isNotEmpty)
                              'age': int.tryParse(age.text.trim()),
                            if (selectedGender != null)
                              'gender': selectedGender,
                            if (phoneNumber != null) 'phone': phoneNumber,
                          },
                        });
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppCopy.text(
                                  'text.error_value1_caf169bf',
                                  arguments: {'value1': (e).toString()},
                                ),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setState(() => loading = false);
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppCopy.text('text.update_6e230e94')),
            ),
          ],
        );
      },
    ),
  );

  _disposeControllers([name, age, phone]);

  if (result == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppCopy.text('text.patient_updated_successfully_1212c7b6'),
        ),
        backgroundColor: Colors.green,
      ),
    );
    onSuccess?.call();
  }
  return result ?? false;
}

// =============================================================================
// COMMON DIALOGS
// =============================================================================

Future<bool> showDeactivateConfirmDialog(
  BuildContext context, {
  required String userId,
  required String userName,
  required String userType,
  required Future<void> Function() onConfirm,
  VoidCallback? onSuccess,
}) async {
  bool loading = false;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: Text(
            AppCopy.text(
              'text.deactivate_value1_e7c0997d',
              arguments: {'value1': (userType).toString()},
            ),
          ),
          content: Text(
            AppCopy.text(
              'text.are_you_sure_you_want_to_deactivate_value1_they__44d38afc',
              arguments: {'value1': (userName).toString()},
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx, false),
              child: Text(AppCopy.text('text.cancel_35afca3b')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: loading
                  ? null
                  : () async {
                      setState(() => loading = true);
                      try {
                        await onConfirm();
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppCopy.text(
                                  'text.error_value1_caf169bf',
                                  arguments: {'value1': (e).toString()},
                                ),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setState(() => loading = false);
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(AppCopy.text('text.deactivate_7fcfb5f3')),
            ),
          ],
        );
      },
    ),
  );

  if (result == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppCopy.text(
            'text.value1_deactivated_be0db93f',
            arguments: {'value1': (userType).toString()},
          ),
        ),
        backgroundColor: Colors.green,
      ),
    );
    onSuccess?.call();
  }
  return result ?? false;
}

Future<bool> showStatusToggleDialog(
  BuildContext context, {
  required bool isActive,
  required String userName,
  required String userType,
  required Future<void> Function() onConfirm,
  VoidCallback? onSuccess,
}) async {
  final action = isActive ? 'Deactivate' : 'Activate';
  bool loading = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: Text('$action $userType'),
          content: Text(
            AppCopy.text(
              'text.are_you_sure_you_want_to_value1_value2_6039f075',
              arguments: {
                'value1': (action).toString(),
                'value2': (userName).toString(),
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx, false),
              child: Text(AppCopy.text('text.cancel_35afca3b')),
            ),
            FilledButton(
              style: isActive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.error,
                    )
                  : null,
              onPressed: loading
                  ? null
                  : () async {
                      setState(() => loading = true);
                      try {
                        await onConfirm();
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppCopy.text(
                                  'text.error_value1_caf169bf',
                                  arguments: {'value1': (e).toString()},
                                ),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setState(() => loading = false);
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(action),
            ),
          ],
        );
      },
    ),
  );

  if (result == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppCopy.text('text.user_status_updated_88558537')),
        backgroundColor: Colors.green,
      ),
    );
    onSuccess?.call();
  }
  return result ?? false;
}

Future<bool> showResetPasswordDialog(
  BuildContext context, {
  required String userId,
  required String userName,

  /// Prefer a V2 credentials-reset callback when available so callers hit the
  /// capability-scoped doctor/patient endpoints instead of the legacy bulk path.
  Future<void> Function(String newPassword)? onReset,
  VoidCallback? onSuccess,
}) async {
  final formKey = GlobalKey<FormState>();
  final passwordCtrl = TextEditingController();
  bool loading = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: Text(
            AppCopy.text(
              'text.reset_password_for_value1_b0e49e1a',
              arguments: {'value1': (userName).toString()},
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: passwordCtrl,
              decoration: InputDecoration(
                labelText: AppCopy.text('text.new_password_a331afd2'),
                prefixIcon: Icon(Icons.lock_rounded),
              ),
              obscureText: true,
              enabled: !loading,
              validator: _validateStrongPassword,
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx, false),
              child: Text(AppCopy.text('text.cancel_35afca3b')),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => loading = true);
                      try {
                        final password = passwordCtrl.text;
                        if (onReset != null) {
                          await onReset(password);
                        } else {
                          await _repo.resetUserPassword(
                            userId,
                            newPassword: password,
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppCopy.text(
                                  'text.error_value1_caf169bf',
                                  arguments: {'value1': (e).toString()},
                                ),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setState(() => loading = false);
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppCopy.text('text.reset_ac8a560')),
            ),
          ],
        );
      },
    ),
  );

  if (result == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppCopy.text('text.password_reset_successfully_a8f54d14'),
        ),
        backgroundColor: Colors.green,
      ),
    );
    onSuccess?.call();
  }
  return result ?? false;
}

Future<bool> showReassignPatientDialog(
  BuildContext context, {
  required String patientOpNum,
  required String currentDoctorId,
  bool resolvingConflict = false,
  List<Map<String, dynamic>> doctors = const [],
  VoidCallback? onSuccess,
}) async {
  String? selectedDoctorId = resolvingConflict
      ? null
      : (currentDoctorId.isNotEmpty ? currentDoctorId : null);

  // Auto-fetch doctors if none provided
  List<Map<String, dynamic>> doctorList = List.from(doctors);
  bool doctorsLoading = doctorList.isEmpty;
  bool doctorsRequested = !doctorsLoading;
  String? doctorsError;
  bool loading = false;
  final doctorSearch = TextEditingController();
  var doctorSearchSequence = 0;
  var doctorHasMore = false;
  var doctorPage = 1;

  Future<void> loadDoctors(
    StateSetter setState,
    BuildContext ctx, {
    bool reset = false,
  }) async {
    final sequence = ++doctorSearchSequence;
    final requestedPage = reset ? 1 : doctorPage + 1;
    await Future<void>.delayed(Duration.zero);
    setState(() {
      doctorsLoading = true;
      doctorsError = null;
    });
    try {
      final response = await _repo.getDoctorAssignmentOptions(
        page: requestedPage,
        search: doctorSearch.text,
      );
      if (!ctx.mounted || sequence != doctorSearchSequence) return;
      final items = (response['doctors'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
      setState(() {
        doctorList = reset ? items : [...doctorList, ...items];
        doctorPage = requestedPage;
        doctorHasMore = pagination['hasNext'] == true || items.length == 20;
        doctorsLoading = false;
      });
    } catch (e) {
      if (!ctx.mounted || sequence != doctorSearchSequence) return;
      setState(() {
        doctorsError = _errorMessage(e);
        doctorsLoading = false;
      });
    }
  }

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        // Fetch doctors on first build if list is empty
        if (!doctorsRequested) {
          doctorsRequested = true;
          loadDoctors(setState, ctx, reset: true);
        }

        return AlertDialog(
          title: Text(AppCopy.text('text.reassign_doctor_55c53170')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                resolvingConflict
                    ? AppCopy.text(
                        'text.select_the_doctor_who_should_own_this_patient_sa_2a95e35a',
                      )
                    : AppCopy.text(
                        'text.select_a_new_doctor_for_this_patient_61bc4f49',
                      ),
              ),
              const SizedBox(height: 16),
              if (doctorsLoading)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text(AppCopy.text('text.loading_doctors_ca2e80f')),
                    ],
                  ),
                )
              else if (doctorsError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    AppCopy.text('text.failed_to_load_doctors_e99e6413'),
                    style: TextStyle(color: Colors.red[700]),
                  ),
                )
              else ...[
                TextField(
                  controller: doctorSearch,
                  decoration: InputDecoration(
                    labelText: AppCopy.text('text.search_doctors_992bbfa1'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: doctorSearch.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              doctorSearch.clear();
                              loadDoctors(setState, ctx, reset: true);
                            },
                          ),
                  ),
                  onChanged: (_) => loadDoctors(setState, ctx, reset: true),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue:
                      doctorList.any(
                        (d) => (d['_id'] ?? d['id']) == selectedDoctorId,
                      )
                      ? selectedDoctorId
                      : null,
                  decoration: InputDecoration(
                    labelText: AppCopy.text('text.new_doctor_e5d7020'),
                    prefixIcon: Icon(Icons.medical_services_rounded),
                  ),
                  items: doctorList.map((d) {
                    final dName =
                        d['name'] as String? ??
                        d['login_id'] as String? ??
                        'Unknown';
                    return DropdownMenuItem(
                      value: d['_id'] as String? ?? d['id'] as String?,
                      child: Text(dName),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => selectedDoctorId = v),
                ),
                if (doctorHasMore)
                  TextButton.icon(
                    onPressed: doctorsLoading
                        ? null
                        : () => loadDoctors(setState, ctx),
                    icon: const Icon(Icons.expand_more),
                    label: Text(
                      AppCopy.text('text.load_more_doctors_13d0685a'),
                    ),
                  ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx, false),
              child: Text(AppCopy.text('text.cancel_35afca3b')),
            ),
            FilledButton(
              onPressed:
                  (loading ||
                      selectedDoctorId == null ||
                      (!resolvingConflict &&
                          selectedDoctorId == currentDoctorId))
                  ? null
                  : () async {
                      setState(() => loading = true);
                      try {
                        await _repo.reassignPatient(
                          patientOpNum,
                          selectedDoctorId!,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppCopy.text(
                                  'text.error_value1_caf169bf',
                                  arguments: {'value1': (e).toString()},
                                ),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setState(() => loading = false);
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppCopy.text('text.reassign_9376a1e1')),
            ),
          ],
        );
      },
    ),
  );

  if (result == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppCopy.text('text.patient_reassigned_successfully_a95fba9c'),
        ),
        backgroundColor: Colors.green,
      ),
    );
    onSuccess?.call();
  }
  doctorSearch.dispose();
  return result ?? false;
}
