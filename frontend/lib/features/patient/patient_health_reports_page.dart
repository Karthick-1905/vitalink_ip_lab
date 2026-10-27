import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/index.dart';
import 'package:frontend/app/routers.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/query/patient_query_keys.dart';

class PatientHealthReportsPage extends StatefulWidget {
  final bool embedInShell;
  final ValueChanged<int>? onTabChanged;

  const PatientHealthReportsPage({
    super.key,
    this.embedInShell = false,
    this.onTabChanged,
  });

  @override
  State<PatientHealthReportsPage> createState() =>
      _PatientHealthReportsPageState();
}

class _PatientHealthReportsPageState extends State<PatientHealthReportsPage> {
  final int _currentNavIndex = 3;
  int _selectedTabIndex = 0;

  // Controllers for text inputs
  final TextEditingController _descriptionController = TextEditingController();

  // Side effects checkboxes
  final Map<String, bool> _sideEffects = {
    'Heavy Menstrual Bleeding': false,
    'Black or Bloody Stool': false,
    'Severe Headache': false,
    'Severe Stomach Pain': false,
    'Joint Pain, Discomfort or Swelling': false,
    'Vomiting of Blood': false,
    'Coughing up Blood': false,
    'Bruising without Injury': false,
    'Dizziness or Weakness': false,
    'Vision Changes': false,
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return _buildPageContainer(
      bodyDecoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC8B5E1), Color(0xFFF8C7D7)],
        ),
      ),
      body: SingleChildScrollView(
        padding: PortalLayout.pagePadding(embedInShell: widget.embedInShell),
        child: Container(
          padding: PortalLayout.cardInsetsComfortable,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(PortalLayout.cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTabBar(),
              PortalLayout.sectionSpacer,
              if (_selectedTabIndex == 0)
                _buildSideEffectsTab()
              else if (_selectedTabIndex == 1)
                _buildIllnessTab()
              else if (_selectedTabIndex == 2)
                _buildLifestyleTab()
              else
                _buildOtherMedsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageContainer({
    required Widget body,
    Decoration? bodyDecoration,
  }) {
    if (widget.embedInShell) {
      return body;
    }

    return PatientScaffold(
      pageTitle: 'Health Reports',
      currentNavIndex: _currentNavIndex,
      bodyDecoration: bodyDecoration,
      onNavChanged: _handleNav,
      body: body,
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        constraints: const BoxConstraints(minWidth: 112),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: isSelected
              ? Border(bottom: BorderSide(color: Colors.pink[400]!, width: 3))
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.pink[400] : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabItem(0, 'Side Effects'),
            _buildTabItem(1, 'Illness'),
            _buildTabItem(2, 'Lifestyle'),
            _buildTabItem(3, 'Other Meds'),
          ],
        ),
      ),
    );
  }

  Widget _buildSideEffectsTab() {
    return UseMutation<void, Map<String, dynamic>>(
      options: MutationOptions<void, Map<String, dynamic>>(
        mutationFn: (variables) => _submitHealthLog(variables),
        onSuccess: (data, variables) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppCopy.text(
                  'text.side_effects_reported_successfully_354f478f',
                ),
              ),
              backgroundColor: Colors.green,
            ),
          );
          _resetForm();
          // Invalidate queries to refetch updated data
          final queryClient = QueryClientProvider.of(context);
          queryClient.invalidateQueries(PatientQueryKeys.profileFull());
          queryClient.invalidateQueries(PatientQueryKeys.recordsFull());
          queryClient.invalidateQueries(PatientQueryKeys.homeData());
        },
        onError: (error, variables) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString()),
              backgroundColor: Colors.red,
            ),
          );
        },
      ),
      builder: (context, mutation) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppCopy.text('text.check_all_that_apply_728b47f1'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Checkboxes
            ..._sideEffects.keys.map((effect) {
              return CheckboxListTile(
                title: Text(effect, style: const TextStyle(fontSize: 14)),
                value: _sideEffects[effect],
                onChanged: (value) {
                  setState(() {
                    _sideEffects[effect] = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),

            const SizedBox(height: 20),
            Text(
              AppCopy.text(
                'text.describe_any_other_side_effects_you_are_experien_5ca8ee53',
              ),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: AppCopy.text(
                  'text.enter_additional_details_6a556176',
                ),
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF0084FF),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: mutation.isLoading
                    ? null
                    : () => _submitSideEffects(mutation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0084FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: mutation.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        AppCopy.text('text.submit_report_2084ec21'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIllnessTab() {
    return _buildTextInputTab(
      'ILLNESS',
      'Report any illness or health condition',
      'Describe your illness, symptoms, and when they started...',
    );
  }

  Widget _buildLifestyleTab() {
    return _buildTextInputTab(
      'LIFESTYLE',
      'Report lifestyle changes',
      'Describe any changes in diet, exercise, sleep patterns, stress levels, etc...',
    );
  }

  Widget _buildOtherMedsTab() {
    return _buildTextInputTab(
      'OTHER_MEDS',
      'Report other medications',
      'List any new medications, supplements, or over-the-counter drugs you are taking...',
    );
  }

  Widget _buildTextInputTab(String type, String title, String hint) {
    return UseMutation<void, Map<String, dynamic>>(
      options: MutationOptions<void, Map<String, dynamic>>(
        mutationFn: (variables) => _submitHealthLog(variables),
        onSuccess: (data, variables) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppCopy.text('text.report_submitted_successfully_d47538ca'),
              ),
              backgroundColor: Colors.green,
            ),
          );
          _resetForm();
          // Invalidate queries to refetch updated data
          final queryClient = QueryClientProvider.of(context);
          queryClient.invalidateQueries(PatientQueryKeys.profileFull());
          queryClient.invalidateQueries(PatientQueryKeys.recordsFull());
          queryClient.invalidateQueries(PatientQueryKeys.homeData());
        },
        onError: (error, variables) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString()),
              backgroundColor: Colors.red,
            ),
          );
        },
      ),
      builder: (context, mutation) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF0084FF),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: mutation.isLoading
                    ? null
                    : () {
                        if (_descriptionController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppCopy.text(
                                  'text.please_enter_a_description_e6db0fcc',
                                ),
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        mutation.mutate({
                          'type': type,
                          'description': _descriptionController.text.trim(),
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0084FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: mutation.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        AppCopy.text('text.submit_report_2084ec21'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _submitSideEffects(MutationResult<void, Map<String, dynamic>> mutation) {
    final selectedEffects = _sideEffects.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    String description = '';
    if (selectedEffects.isNotEmpty) {
      description = selectedEffects.join(', ');
    }
    if (_descriptionController.text.trim().isNotEmpty) {
      if (description.isNotEmpty) {
        description +=
            '\n\nAdditional details: ${_descriptionController.text.trim()}';
      } else {
        description = _descriptionController.text.trim();
      }
    }

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppCopy.text(
              'text.please_select_at_least_one_side_effect_or_enter__c3513a17',
            ),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    mutation.mutate({'type': 'SIDE_EFFECT', 'description': description});
  }

  Future<void> _submitHealthLog(Map<String, dynamic> variables) async {
    await AppDependencies.patientRepository.submitHealthLog(
      type: variables['type'] as String,
      description: variables['description'] as String,
    );
  }

  void _resetForm() {
    setState(() {
      _descriptionController.clear();
      _sideEffects.updateAll((key, value) => false);
    });
  }

  void _handleNav(int index) {
    if (index == _currentNavIndex) return;
    if (widget.embedInShell) {
      widget.onTabChanged?.call(index);
      return;
    }
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacementNamed(AppRoutes.patient);
        break;
      case 1:
        Navigator.of(context).pushReplacementNamed(AppRoutes.patientUpdateINR);
        break;
      case 2:
        Navigator.of(context).pushReplacementNamed(AppRoutes.patientTakeDosage);
        break;
      case 3:
        break;
      case 4:
        Navigator.of(context).pushReplacementNamed(AppRoutes.patientProfile);
        break;
    }
  }
}
