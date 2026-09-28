import 'package:flutter/material.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/widgets/admin/admin_scaffold.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';

class NotificationBroadcastPage extends StatefulWidget {
  const NotificationBroadcastPage({super.key, this.repository});

  final AdminRepository? repository;

  @override
  State<NotificationBroadcastPage> createState() =>
      _NotificationBroadcastPageState();
}

class _NotificationBroadcastPageState extends State<NotificationBroadcastPage> {
  late final AdminRepository _repo;
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _customUserIdCtrl = TextEditingController();

  String _target = 'ALL';
  String _priority = 'MEDIUM';
  bool _isSending = false;

  String? _selectedUserId;
  String? _selectedUserLabel;
  bool _useManualUserId = false;

  List<Map<String, dynamic>> _doctors = [];
  bool _loadingDoctors = false;
  String? _doctorsError;
  bool _doctorsFetched = false;

  List<Map<String, dynamic>> _patients = [];
  bool _loadingPatients = false;
  String? _patientsError;
  bool _patientsFetched = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AppDependencies.adminRepository;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _customUserIdCtrl.dispose();
    super.dispose();
  }

  void _selectTarget(String target) {
    if (_target == target) return;
    setState(() {
      _target = target;
      _selectedUserId = null;
      _selectedUserLabel = null;
      _customUserIdCtrl.clear();
      _useManualUserId = false;
    });

    if (target == 'SPECIFIC_DOCTOR' && !_doctorsFetched) {
      _loadDoctors();
    } else if (target == 'SPECIFIC_PATIENT' && !_patientsFetched) {
      _loadPatients();
    }
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _loadingDoctors = true;
      _doctorsError = null;
    });
    try {
      final res = await _repo.getAllDoctors(limit: 100, isActive: 'true');
      final list =
          (res['doctors'] as List? ?? []).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _doctors = list;
          _doctorsFetched = true;
          _loadingDoctors = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _doctorsError = e.toString();
          _doctorsFetched = true;
          _loadingDoctors = false;
        });
      }
    }
  }

  Future<void> _loadPatients() async {
    setState(() {
      _loadingPatients = true;
      _patientsError = null;
    });
    try {
      final res = await _repo.getAllPatients(limit: 100);
      final list =
          (res['patients'] as List? ?? []).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _patients = list;
          _patientsFetched = true;
          _loadingPatients = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _patientsError = e.toString();
          _patientsFetched = true;
          _loadingPatients = false;
        });
      }
    }
  }

  String _doctorName(Map<String, dynamic> d) {
    final profile = d['profile_id'] as Map<String, dynamic>? ??
        d['profile'] as Map<String, dynamic>? ??
        {};
    return profile['name'] as String? ??
        d['name'] as String? ??
        d['login_id'] as String? ??
        'Unknown Doctor';
  }

  String _doctorSubtitle(Map<String, dynamic> d) {
    final profile = d['profile_id'] as Map<String, dynamic>? ??
        d['profile'] as Map<String, dynamic>? ??
        {};
    final dept = profile['department'] as String? ?? '';
    final loginId = d['login_id'] as String? ?? '';
    final parts = [
      if (dept.isNotEmpty) dept,
      if (loginId.isNotEmpty) 'ID: $loginId',
    ];
    return parts.join(' • ');
  }

  String _doctorId(Map<String, dynamic> d) {
    return (d['_id'] ?? d['id'])?.toString() ?? '';
  }

  String _patientName(Map<String, dynamic> p) {
    final profile = p['profile_id'] as Map<String, dynamic>? ??
        p['profile'] as Map<String, dynamic>? ??
        {};
    final demographics =
        profile['demographics'] as Map<String, dynamic>? ?? {};
    return demographics['name'] as String? ??
        p['name'] as String? ??
        p['login_id'] as String? ??
        'Unknown Patient';
  }

  String _patientSubtitle(Map<String, dynamic> p) {
    final profile = p['profile_id'] as Map<String, dynamic>? ??
        p['profile'] as Map<String, dynamic>? ??
        {};
    final opNum =
        profile['op_number'] as String? ?? p['login_id'] as String? ?? '';
    return opNum.isNotEmpty ? 'OP: $opNum' : '';
  }

  String _patientId(Map<String, dynamic> p) {
    return (p['_id'] ?? p['id'])?.toString() ?? '';
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    final isSpecific =
        _target == 'SPECIFIC_DOCTOR' || _target == 'SPECIFIC_PATIENT';
    final targetUserId = _useManualUserId
        ? _customUserIdCtrl.text.trim()
        : _selectedUserId?.trim();

    if (isSpecific && (targetUserId == null || targetUserId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a recipient User ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String confirmText;
    if (_target == 'SPECIFIC_DOCTOR') {
      final label = _selectedUserLabel ?? targetUserId!;
      confirmText =
          'This will send a $_priority priority notification to doctor $label.';
    } else if (_target == 'SPECIFIC_PATIENT') {
      final label = _selectedUserLabel ?? targetUserId!;
      confirmText =
          'This will send a $_priority priority notification to patient $label.';
    } else {
      confirmText =
          'This will broadcast a $_priority priority notification to ${_target.toLowerCase()} users.';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Notification?'),
        content: Text(confirmText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSending = true);
    try {
      await _repo.broadcastNotification(
        title: _titleCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        target: isSpecific ? 'SPECIFIC' : _target,
        userIds: isSpecific ? [targetUserId!] : null,
        priority: _priority,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _titleCtrl.clear();
        _messageCtrl.clear();
        _customUserIdCtrl.clear();
        setState(() {
          _target = 'ALL';
          _priority = 'MEDIUM';
          _selectedUserId = null;
          _selectedUserLabel = null;
          _useManualUserId = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildRecipientSelector(ThemeData theme) {
    final isDoctor = _target == 'SPECIFIC_DOCTOR';
    final isLoading = isDoctor ? _loadingDoctors : _loadingPatients;
    final hasError =
        (isDoctor ? _doctorsError : _patientsError) != null;
    final items = isDoctor ? _doctors : _patients;
    final title = isDoctor ? 'Target Doctor' : 'Target Patient';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDoctor
                      ? Icons.medical_services_outlined
                      : Icons.person_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!isLoading && !hasError && items.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _useManualUserId = !_useManualUserId;
                        _selectedUserId = null;
                        _customUserIdCtrl.clear();
                      });
                    },
                    icon: Icon(
                      _useManualUserId
                          ? Icons.list_rounded
                          : Icons.edit_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _useManualUserId
                          ? 'Select from list'
                          : 'Enter ID manually',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_useManualUserId) ...[
              TextFormField(
                controller: _customUserIdCtrl,
                decoration: InputDecoration(
                  labelText: isDoctor
                      ? 'Doctor User ID (24-char hex)'
                      : 'Patient User ID (24-char hex)',
                  hintText: 'e.g. 507f1f77bcf86cd799439011',
                  prefixIcon: const Icon(Icons.tag_rounded),
                  border: const OutlineInputBorder(),
                ),
                enabled: !_isSending,
                validator: (v) {
                  final val = v?.trim() ?? '';
                  if (val.isEmpty) return 'Recipient User ID is required';
                  if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(val)) {
                    return 'Must be a 24-character hexadecimal ID';
                  }
                  return null;
                },
              ),
            ] else if (isLoading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading ${isDoctor ? 'doctors' : 'patients'}...',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ] else if (hasError || items.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasError
                          ? 'Unable to load ${isDoctor ? 'doctors' : 'patients'} directory in current administrator scope.'
                          : 'No active ${isDoctor ? 'doctors' : 'patients'} found.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You can enter the recipient\'s 24-character User ID directly below.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customUserIdCtrl,
                decoration: InputDecoration(
                  labelText: isDoctor
                      ? 'Doctor User ID (24-char hex)'
                      : 'Patient User ID (24-char hex)',
                  hintText: 'e.g. 507f1f77bcf86cd799439011',
                  prefixIcon: const Icon(Icons.tag_rounded),
                  border: const OutlineInputBorder(),
                ),
                enabled: !_isSending,
                validator: (v) {
                  final val = v?.trim() ?? '';
                  if (val.isEmpty) return 'Recipient User ID is required';
                  if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(val)) {
                    return 'Must be a 24-character hexadecimal ID';
                  }
                  return null;
                },
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedUserId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: isDoctor ? 'Select Doctor' : 'Select Patient',
                  prefixIcon: Icon(
                    isDoctor
                        ? Icons.medical_services_rounded
                        : Icons.person_rounded,
                  ),
                  border: const OutlineInputBorder(),
                ),
                items: items.map((item) {
                  final id = isDoctor ? _doctorId(item) : _patientId(item);
                  final name = isDoctor ? _doctorName(item) : _patientName(item);
                  final sub = isDoctor
                      ? _doctorSubtitle(item)
                      : _patientSubtitle(item);
                  return DropdownMenuItem<String>(
                    value: id,
                    child: Text(
                      sub.isNotEmpty ? '$name ($sub)' : name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedUserId = val;
                    if (val != null) {
                      final chosen = items.firstWhere(
                        (it) =>
                            (isDoctor ? _doctorId(it) : _patientId(it)) == val,
                        orElse: () => <String, dynamic>{},
                      );
                      _selectedUserLabel = isDoctor
                          ? _doctorName(chosen)
                          : _patientName(chosen);
                    }
                  });
                },
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please select a ${isDoctor ? 'doctor' : 'patient'}';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showPageScaffold = !AdminScaffold.usesShellAppBar(context);
    final isSpecific =
        _target == 'SPECIFIC_DOCTOR' || _target == 'SPECIFIC_PATIENT';

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!showPageScaffold)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Broadcast Notification',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            // Info card
            Card(
              color: theme.colorScheme.primaryContainer.withValues(
                alpha: 0.3,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Broadcast a notification to user groups or directly to an individual doctor or patient.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Notification Title',
                prefixIcon: Icon(Icons.title_rounded),
                border: OutlineInputBorder(),
              ),
              enabled: !_isSending,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),

            // Message
            TextFormField(
              controller: _messageCtrl,
              decoration: const InputDecoration(
                labelText: 'Message',
                prefixIcon: Icon(Icons.message_rounded),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              enabled: !_isSending,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Message is required'
                  : null,
            ),
            const SizedBox(height: 24),

            // Target
            Text(
              'Target Audience',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TargetChip(
                  label: 'All Users',
                  value: 'ALL',
                  icon: Icons.groups_rounded,
                  selected: _target == 'ALL',
                  onTap: () => _selectTarget('ALL'),
                ),
                _TargetChip(
                  label: 'All Doctors',
                  value: 'DOCTORS',
                  icon: Icons.medical_services_rounded,
                  selected: _target == 'DOCTORS',
                  onTap: () => _selectTarget('DOCTORS'),
                ),
                _TargetChip(
                  label: 'All Patients',
                  value: 'PATIENTS',
                  icon: Icons.people_rounded,
                  selected: _target == 'PATIENTS',
                  onTap: () => _selectTarget('PATIENTS'),
                ),
                _TargetChip(
                  label: 'Specific Doctor',
                  value: 'SPECIFIC_DOCTOR',
                  icon: Icons.person_search_rounded,
                  selected: _target == 'SPECIFIC_DOCTOR',
                  onTap: () => _selectTarget('SPECIFIC_DOCTOR'),
                ),
                _TargetChip(
                  label: 'Specific Patient',
                  value: 'SPECIFIC_PATIENT',
                  icon: Icons.person_pin_rounded,
                  selected: _target == 'SPECIFIC_PATIENT',
                  onTap: () => _selectTarget('SPECIFIC_PATIENT'),
                ),
              ],
            ),
            if (isSpecific) ...[
              const SizedBox(height: 16),
              _buildRecipientSelector(theme),
            ],
            const SizedBox(height: 24),

            // Priority
            Text(
              'Priority',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final priorityControl = SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'LOW',
                      label: Text('Low'),
                      icon: Icon(Icons.arrow_downward_rounded),
                    ),
                    ButtonSegment(
                      value: 'MEDIUM',
                      label: Text('Medium'),
                      icon: Icon(Icons.remove_rounded),
                    ),
                    ButtonSegment(
                      value: 'HIGH',
                      label: Text('High'),
                      icon: Icon(Icons.arrow_upward_rounded),
                    ),
                    ButtonSegment(
                      value: 'URGENT',
                      label: Text('Urgent'),
                      icon: Icon(Icons.warning_rounded),
                    ),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (v) =>
                      setState(() => _priority = v.first),
                );

                if (constraints.maxWidth >= 430) return priorityControl;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: priorityControl,
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Send button
            FilledButton.icon(
              onPressed: _isSending ? null : _send,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_isSending ? 'Sending...' : 'Send Notification'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );

    if (!showPageScaffold) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Broadcast Notification')),
      body: content,
    );
  }
}

class _TargetChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TargetChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: selected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
