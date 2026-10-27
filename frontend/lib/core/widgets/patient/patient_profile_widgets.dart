import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/app/routers.dart';
import 'package:frontend/core/utils/phone_utils.dart';
import 'package:frontend/core/widgets/index.dart';

class PatientProfileContent extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onProfileUpdated;

  const PatientProfileContent({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The page already removes 40 logical pixels for horizontal padding.
        // Keep the regular two-column phone layout at common 320-350px content
        // widths and reserve the stacked fallback for genuinely narrow spaces.
        final isNarrow = constraints.maxWidth < 300;
        final useSmallerHeader = constraints.maxWidth < 340;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isNarrow)
              Column(
                children: [
                  _buildAvatar(),
                  PortalLayout.sectionSpacerTight,
                  _buildHeaderDetails(isCentered: true),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatar(diameter: useSmallerHeader ? 88 : 100),
                  SizedBox(
                    width: useSmallerHeader
                        ? PortalLayout.cardPadding
                        : PortalLayout.cardPaddingComfortable,
                  ),
                  Expanded(child: _buildHeaderDetails()),
                ],
              ),
            PortalLayout.sectionSpacer,

            // Info Cards — dense clinical facts
            if (isNarrow)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PatientInfoSmallCard(
                    icon: Icons.calendar_today,
                    label: AppCopy.text('text.age_8ecbe13c'),
                    value: '${profile['age'] ?? 'N/A'} yrs',
                    color: const Color(0xFFFF7643),
                  ),
                  PortalLayout.itemSpacer,
                  PatientInfoSmallCard(
                    icon: profile['gender'] == 'Female'
                        ? Icons.female
                        : Icons.male,
                    label: AppCopy.text('text.gender_a72c0ba0'),
                    value: profile['gender'] ?? 'N/A',
                    color: const Color(0xFF10B981),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: PatientInfoSmallCard(
                      icon: Icons.calendar_today,
                      label: AppCopy.text('text.age_8ecbe13c'),
                      value: '${profile['age'] ?? 'N/A'} yrs',
                      color: const Color(0xFFFF7643),
                    ),
                  ),
                  PortalLayout.columnSpacer,
                  Expanded(
                    child: PatientInfoSmallCard(
                      icon: profile['gender'] == 'Female'
                          ? Icons.female
                          : Icons.male,
                      label: AppCopy.text('text.gender_a72c0ba0'),
                      value: profile['gender'] ?? 'N/A',
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            PortalLayout.itemSpacer,

            PatientInfoCard(
              icon: Icons.medical_services,
              label: AppCopy.text('text.therapy_drug_5d5334d0'),
              value: profile['therapyDrug'] ?? 'Warfarin',
              color: const Color(0xFF8B5CF6),
            ),
            PortalLayout.itemSpacer,

            if (profile['doctorName'] != null) ...[
              PatientInfoCard(
                icon: Icons.person,
                label: AppCopy.text('text.assigned_doctor_2c77d0e4'),
                value: profile['doctorName']!,
                color: const Color(0xFF3B82F6),
              ),
              PortalLayout.itemSpacer,
            ],

            // Profile Details Section
            PatientProfileDetails(profile: profile),
            PortalLayout.sectionSpacer,

            // Action Buttons
            PatientActionButtons(
              profile: profile,
              onProfileUpdated: onProfileUpdated,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvatar({double diameter = 100}) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFFA5B4FC)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: profile['profilePictureUrl'] != null
          ? ClipOval(
              child: Image.network(
                profile['profilePictureUrl']!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    PatientAvatarPlaceholder(name: profile['name'] ?? 'P'),
              ),
            )
          : PatientAvatarPlaceholder(name: profile['name'] ?? 'P'),
    );
  }

  Widget _buildHeaderDetails({bool isCentered = false}) {
    return Column(
      crossAxisAlignment: isCentered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          profile['name'] ?? AppCopy.text('text.patient_name_1d86ace1'),
          textAlign: isCentered ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        if ((profile['opNumber']?.toString().trim().isNotEmpty ?? false)) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFC7D2FE), width: 1),
            ),
            child: Text(
              AppCopy.text(
                'text.op_value1_38c57f2b',
                arguments: {'value1': (profile['opNumber']).toString()},
              ),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4338CA),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
          ),
          child: Text(
            AppCopy.text(
              'text.target_inr_value1_8126a029',
              arguments: {
                'value1': (profile['targetINR'] ?? '2.0 - 3.0').toString(),
              },
            ),
            textAlign: isCentered ? TextAlign.center : TextAlign.start,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6366F1),
            ),
          ),
        ),
      ],
    );
  }
}

class PatientAvatarPlaceholder extends StatelessWidget {
  final String name;

  const PatientAvatarPlaceholder({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();
    String initials;
    if (parts.isEmpty) {
      initials = 'P';
    } else if (parts.length == 1) {
      initials = parts[0][0].toUpperCase();
    } else {
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class PatientInfoSmallCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const PatientInfoSmallCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class PatientInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const PatientInfoCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PatientProfileDetails extends StatelessWidget {
  final Map<String, dynamic> profile;

  const PatientProfileDetails({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppCopy.text('text.personal_details_1687a8ff'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          PatientDetailRow(
            label: AppCopy.text('text.phone_4930944f'),
            value: profile['phone'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          PatientDetailRow(
            label: AppCopy.text('text.caregiver_ae2c28ad'),
            value: profile['caregiver'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          PatientDetailRow(
            label: AppCopy.text('text.kin_name_6cf8bbcc'),
            value: profile['kinName'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          PatientDetailRow(
            label: AppCopy.text('text.kin_phone_9521f96d'),
            value: profile['kinPhone'] ?? 'N/A',
          ),
          const SizedBox(height: 16),
          Text(
            AppCopy.text('text.therapy_details_488741e8'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          PatientDetailRow(
            label: AppCopy.text('text.start_date_1a637601'),
            value: profile['therapyStartDate'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          PatientDetailRow(
            label: AppCopy.text('text.next_review_fbb4bd7c'),
            value: profile['nextReviewDate'] ?? 'N/A',
          ),
        ],
      ),
    );
  }
}

class PatientDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const PatientDetailRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;

        return isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              );
      },
    );
  }
}

class PatientActionButtons extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onProfileUpdated;

  const PatientActionButtons({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => PatientEditProfileModal(
                profile: profile,
                onSuccess: () {
                  Navigator.of(ctx).pop();
                  onProfileUpdated();
                },
              ),
            );
          },
          icon: const Icon(Icons.edit, size: 20),
          label: Text(AppCopy.text('text.update_profile_d44bd129')),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(
              context,
            ).pushNamed(AppRoutes.changePassword, arguments: false);
          },
          icon: const Icon(Icons.lock_outline, size: 20),
          label: Text(AppCopy.text('text.change_password_87f6bf6e')),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4338CA),
            side: const BorderSide(color: Color(0xFFC7D2FE), width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showLogoutConfirmation(context),
          icon: const Icon(Icons.logout, size: 20),
          label: Text(AppCopy.text('text.logout_877a6a0b')),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => LogoutDialog(onLogout: () => _performLogout(context)),
    );
  }

  Future<void> _performLogout(BuildContext context) async {
    await AppDependencies.authRepository.logout();
    await QueryCache.instance.clear();
    if (context.mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }
}

class PatientEditProfileModal extends StatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onSuccess;

  const PatientEditProfileModal({
    super.key,
    required this.profile,
    required this.onSuccess,
  });

  @override
  State<PatientEditProfileModal> createState() =>
      _PatientEditProfileModalState();
}

class _PatientEditProfileModalState extends State<PatientEditProfileModal> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _phoneController;
  late final TextEditingController _caregiverController;
  late final TextEditingController _kinNameController;
  late final TextEditingController _kinPhoneController;
  late final TextEditingController _therapyStartController;

  String? _selectedGender;
  bool _isLoading = false;
  String? _error;

  /// Treat placeholder values like "N/A" as empty for form fields.
  static String _displayOrEmpty(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toUpperCase() == 'N/A') return '';
    return text;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile['name']);
    _ageController = TextEditingController(
      text: widget.profile['age']?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text: PhoneUtils.toLocalDigits(widget.profile['phone']?.toString()),
    );
    // Caregiver maps to next_of_kin.relation; kin name maps to next_of_kin.name.
    _caregiverController = TextEditingController(
      text: _displayOrEmpty(widget.profile['kinRelation']),
    );
    _kinNameController = TextEditingController(
      text: _displayOrEmpty(widget.profile['kinName']),
    );
    _kinPhoneController = TextEditingController(
      text: PhoneUtils.toLocalDigits(widget.profile['kinPhone']?.toString()),
    );
    // Therapy start is clinician-owned; show for context only (not submitted).
    final therapyStart = _displayOrEmpty(widget.profile['therapyStartDate']);
    _therapyStartController = TextEditingController(text: therapyStart);
    final gender = widget.profile['gender']?.toString();
    _selectedGender =
        (gender == 'Male' || gender == 'Female' || gender == 'Other')
        ? gender
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _caregiverController.dispose();
    _kinNameController.dispose();
    _kinPhoneController.dispose();
    _therapyStartController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Backend updateProfileSchema is strict and only accepts demographics
      // (+ medical_history). medical_config / therapy_start_date are doctor-only
      // and are rejected with "Validation failed" if sent.
      final demographics = <String, dynamic>{};

      demographics['name'] = _nameController.text.trim();
      if (_ageController.text.isNotEmpty) {
        final age = int.tryParse(_ageController.text.trim());
        if (age != null && age > 0) {
          demographics['age'] = age;
        }
      }
      if (_selectedGender != null) {
        demographics['gender'] = _selectedGender;
      }
      final phoneNumber = PhoneUtils.formatForApi(_phoneController.text);
      if (phoneNumber != null) {
        demographics['phone'] = phoneNumber;
      }

      final nextOfKin = <String, dynamic>{};
      final kinName = _kinNameController.text.trim();
      if (kinName.isNotEmpty && kinName.toUpperCase() != 'N/A') {
        nextOfKin['name'] = kinName;
      }
      final kinPhone = PhoneUtils.formatForApi(_kinPhoneController.text);
      if (kinPhone != null) {
        nextOfKin['phone'] = kinPhone;
      }
      final caregiver = _caregiverController.text.trim();
      if (caregiver.isNotEmpty && caregiver.toUpperCase() != 'N/A') {
        nextOfKin['relation'] = caregiver;
      }
      if (nextOfKin.isNotEmpty) {
        demographics['next_of_kin'] = nextOfKin;
      }

      await AppDependencies.patientRepository.updateProfile(
        demographics: demographics,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppCopy.text('text.profile_updated_successfully_d53e34c6'),
            ),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppCopy.text('text.update_profile_d44bd129'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppCopy.text(
                        'text.keep_your_medical_and_contact_information_curren_92976146',
                      ),
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildSectionTitle('Demographics'),
                    _buildTextField(
                      controller: _nameController,
                      label: AppCopy.text('text.name_fe07306'),
                      icon: Icons.person_outline,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 380;

                        return isCompact
                            ? Column(
                                children: [
                                  _buildTextField(
                                    controller: _ageController,
                                    label: AppCopy.text('text.age_8ecbe13c'),
                                    icon: Icons.calendar_today_outlined,
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDropdownField(
                                    label: AppCopy.text('text.gender_a72c0ba0'),
                                    value: _selectedGender,
                                    items: ['Male', 'Female', 'Other'],
                                    onChanged: (v) =>
                                        setState(() => _selectedGender = v),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _ageController,
                                      label: AppCopy.text('text.age_8ecbe13c'),
                                      icon: Icons.calendar_today_outlined,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildDropdownField(
                                      label: AppCopy.text(
                                        'text.gender_a72c0ba0',
                                      ),
                                      value: _selectedGender,
                                      items: ['Male', 'Female', 'Other'],
                                      onChanged: (v) =>
                                          setState(() => _selectedGender = v),
                                    ),
                                  ),
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: AppCopy.text('text.phone_number_f25088d8'),
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      helperText: AppCopy.text(
                        'text.91_is_added_automatically_10a7eeeb',
                      ),
                      validator: (v) => PhoneUtils.validate(
                        v,
                        label: AppCopy.text('text.phone_4930944f'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Caregiver & Kin'),
                    _buildTextField(
                      controller: _caregiverController,
                      label: AppCopy.text('text.caregiver_name_e148e694'),
                      icon: Icons.handshake_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _kinNameController,
                      label: AppCopy.text('text.next_of_kin_name_eedb63ce'),
                      icon: Icons.family_restroom_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _kinPhoneController,
                      label: AppCopy.text('text.kin_phone_number_7fc307d6'),
                      icon: Icons.contact_phone_outlined,
                      keyboardType: TextInputType.phone,
                      helperText: AppCopy.text(
                        'text.use_a_10_digit_indian_number_a56679a4',
                      ),
                      validator: (v) => PhoneUtils.validate(
                        v,
                        label: AppCopy.text('text.kin_phone_9521f96d'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Therapy Configuration'),
                    _buildTextField(
                      controller: _therapyStartController,
                      label: AppCopy.text(
                        'text.start_date_dd_mm_yyyy_60ab8a88',
                      ),
                      icon: Icons.date_range_outlined,
                      readOnly: true,
                      helperText: AppCopy.text(
                        'text.managed_by_your_doctor_not_editable_here_10f176b0',
                      ),
                      suffixIcon: const Icon(
                        Icons.lock_outline,
                        color: Color(0xFF9CA3AF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 32),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 380;

                        return isCompact
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _saveProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6366F1),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            AppCopy.text(
                                              'text.save_changes_174a0119',
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF6B7280),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      AppCopy.text('text.cancel_35afca3b'),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => Navigator.of(context).pop(),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF6B7280,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        AppCopy.text('text.cancel_35afca3b'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _saveProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF6366F1,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              AppCopy.text(
                                                'text.save_changes_174a0119',
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9CA3AF),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
        suffixIcon: suffixIcon,
        helperText: helperText,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
