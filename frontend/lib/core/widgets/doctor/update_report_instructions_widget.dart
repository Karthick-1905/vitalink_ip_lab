import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/features/doctor/models/report_model.dart';
import 'package:intl/intl.dart';

class UpdateReportInstructionsWidget extends StatefulWidget {
  final String opNumber;
  final String reportId;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const UpdateReportInstructionsWidget({
    super.key,
    required this.opNumber,
    required this.reportId,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<UpdateReportInstructionsWidget> createState() =>
      _UpdateReportInstructionsWidgetState();
}

class _UpdateReportInstructionsWidgetState
    extends State<UpdateReportInstructionsWidget> {
  late TextEditingController _notesController;
  late Future<Map<String, dynamic>> _reportFuture;
  bool _isCritical = false;
  bool _isUpdating = false;
  bool _isFormInitialized = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _reportFuture = _createReportFuture();
  }

  @override
  void didUpdateWidget(covariant UpdateReportInstructionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opNumber != widget.opNumber ||
        oldWidget.reportId != widget.reportId) {
      _reportFuture = _createReportFuture();
      _isFormInitialized = false;
      _isCritical = false;
      _notesController.clear();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _createReportFuture() {
    return AppDependencies.doctorRepository.getReport(
      widget.opNumber,
      widget.reportId,
    );
  }

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _reportFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          debugPrint('Error loading report: ${snapshot.error}');
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData) {
          return _buildEmptyState();
        }

        final reportData = snapshot.data!;
        final report = ReportModel.fromJson(reportData);

        if (!_isFormInitialized) {
          _notesController.text = report.notes ?? '';
          _isCritical = report.isCritical;
          _isFormInitialized = true;
        }

        return _buildUpdateForm(report);
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(AppCopy.text('text.loading_report_78ab2a27')),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            AppCopy.text('text.error_loading_report_e9d570d1'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close),
            label: Text(AppCopy.text('text.close_cd86acc3')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            AppCopy.text('text.no_report_data_a6aa36bc'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close),
            label: Text(AppCopy.text('text.close_cd86acc3')),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateForm(ReportModel report) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppCopy.text('text.update_report_7cd6170e'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppCopy.text(
                          'text.inr_value1_value2_4b732249',
                          arguments: {
                            'value1': (report.inrValue.toStringAsFixed(
                              2,
                            )).toString(),
                            'value2': (DateFormat(
                              'MMM dd, yyyy',
                            ).format(report.testDate)).toString(),
                          },
                        ),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onCancel,
                ),
              ],
            ),
          ),
          const Divider(),
          // Form content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Report Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppCopy.text('text.report_reference_b27fc26e'),
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              report.id,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontFamily: 'monospace',
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Notes Field
                Text(
                  AppCopy.text('text.doctor_s_notes_2512e421'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 5,
                  minLines: 3,
                  decoration: InputDecoration(
                    hintText: AppCopy.text(
                      'text.add_or_update_notes_about_this_report_ff47e46',
                    ),
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF6366F1),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                // Critical Status Toggle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isCritical ? Colors.red[50] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isCritical ? Colors.red[200]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppCopy.text('text.mark_as_critical_12577a41'),
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: _isCritical ? Colors.red[700] : null,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppCopy.text(
                                'text.flag_this_report_for_immediate_attention_1777c4c1',
                              ),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isCritical,
                        onChanged: (value) {
                          setState(() => _isCritical = value);
                        },
                        activeThumbColor: Colors.red[600],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUpdating ? null : widget.onCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(AppCopy.text('text.cancel_35afca3b')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUpdating ? null : () => _updateReport(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isUpdating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(AppCopy.text('text.update_report_7cd6170e')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateReport() async {
    try {
      setState(() => _isUpdating = true);

      await AppDependencies.doctorRepository.updateReportInstructions(
        widget.opNumber,
        widget.reportId,
        notes: _notesController.text,
        isCritical: _isCritical,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppCopy.text('text.report_updated_successfully_2aea82b9'),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }
}
