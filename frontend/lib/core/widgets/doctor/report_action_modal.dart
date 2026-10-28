import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/doctor/view_report_widget.dart';
import 'package:frontend/core/widgets/doctor/update_report_instructions_widget.dart';

/// Enum to track which action is being displayed
enum ReportAction { view, update }

/// Modal widget for displaying report details and update form
class ReportActionModal extends StatefulWidget {
  final String opNumber;
  final String reportId;
  final ReportAction initialAction;
  final VoidCallback? onClose;

  const ReportActionModal({
    super.key,
    required this.opNumber,
    required this.reportId,
    this.initialAction = ReportAction.view,
    this.onClose,
  });

  @override
  State<ReportActionModal> createState() => _ReportActionModalState();

  /// Show as bottom sheet
  static Future<void> showAsBottomSheet(
    BuildContext context, {
    required String opNumber,
    required String reportId,
    ReportAction initialAction = ReportAction.view,
    VoidCallback? onClose,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ReportActionModal(
        opNumber: opNumber,
        reportId: reportId,
        initialAction: initialAction,
        onClose: onClose,
      ),
    );
  }

  /// Show as dialog
  static Future<void> showAsDialog(
    BuildContext context, {
    required String opNumber,
    required String reportId,
    ReportAction initialAction = ReportAction.view,
    VoidCallback? onClose,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: ReportActionModal(
          opNumber: opNumber,
          reportId: reportId,
          initialAction: initialAction,
          onClose: onClose,
        ),
      ),
    );
  }
}

class _ReportActionModalState extends State<ReportActionModal> {
  late ReportAction _currentAction;

  @override
  void initState() {
    super.initState();
    _currentAction = widget.initialAction;
  }

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final isMobileView = MediaQuery.of(context).size.height < 600;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        children: [
          // Tab selector for switching between View and Update
          if (!isMobileView) _buildTabSelector() else const SizedBox.shrink(),
          // Content area
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: AppCopy.text('text.view_details_e2c15a0e'),
              action: ReportAction.view,
              isSelected: _currentAction == ReportAction.view,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTabButton(
              label: AppCopy.text('text.update_notes_2259b6c1'),
              action: ReportAction.update,
              isSelected: _currentAction == ReportAction.update,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required ReportAction action,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _currentAction = action),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentAction) {
      case ReportAction.view:
        return ViewReportWidget(
          opNumber: widget.opNumber,
          reportId: widget.reportId,
          onBack: _handleClose,
        );
      case ReportAction.update:
        return UpdateReportInstructionsWidget(
          opNumber: widget.opNumber,
          reportId: widget.reportId,
          onSuccess: _handleSuccess,
          onCancel: _handleClose,
        );
    }
  }

  void _handleClose() {
    Navigator.of(context).pop();
    widget.onClose?.call();
  }

  void _handleSuccess() {
    Navigator.of(context).pop();
    widget.onClose?.call();
  }
}
