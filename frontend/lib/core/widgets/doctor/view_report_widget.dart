import 'package:flutter/material.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/features/doctor/models/report_model.dart';
import 'package:frontend/core/widgets/common/file_preview_modal.dart';
import 'package:intl/intl.dart';

class ViewReportWidget extends StatefulWidget {
  final String opNumber;
  final String reportId;
  final VoidCallback onBack;

  const ViewReportWidget({
    super.key,
    required this.opNumber,
    required this.reportId,
    required this.onBack,
  });

  @override
  State<ViewReportWidget> createState() => _ViewReportWidgetState();
}

class _ViewReportWidgetState extends State<ViewReportWidget> {
  bool _isPreviewMode = false;
  late Future<Map<String, dynamic>> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _loadReport();
  }

  @override
  void didUpdateWidget(covariant ViewReportWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opNumber != widget.opNumber ||
        oldWidget.reportId != widget.reportId) {
      _isPreviewMode = false;
      _reportFuture = _loadReport();
    }
  }

  Future<Map<String, dynamic>> _loadReport() {
    return AppDependencies.doctorRepository.getReport(
      widget.opNumber,
      widget.reportId,
    );
  }

  @override
  Widget build(BuildContext context) {
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
        final targetMin = _targetMinFrom(reportData);
        final targetMax = _targetMaxFrom(reportData);

        return _isPreviewMode
            ? _buildPreviewMode(report, targetMin: targetMin, targetMax: targetMax)
            : _buildDetailMode(report, targetMin: targetMin, targetMax: targetMax);
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
          const Text('Loading report...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading report',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
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
            'No report data',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMode(
    ReportModel report, {
    double targetMin = 2.0,
    double targetMax = 3.0,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
                Expanded(
                  child: Text(
                    'Report Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Report content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // INR Value - Main highlight
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _getINRGradientColors(
                        report.inrValue,
                        isCritical: report.isCritical,
                        min: targetMin,
                        max: targetMax,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _getINRColor(
                          report.inrValue,
                          isCritical: report.isCritical,
                          min: targetMin,
                          max: targetMax,
                        ).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INR Value',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report.inrValue.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getINRStatus(
                            report.inrValue,
                            isCritical: report.isCritical,
                            min: targetMin,
                            max: targetMax,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Test Date
                _buildInfoRow(
                  label: 'Test Date',
                  value: DateFormat('MMM dd, yyyy').format(report.testDate),
                  icon: Icons.calendar_today,
                ),
                const SizedBox(height: 16),
                // Critical Status
                if (report.isCritical)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red[700],
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'CRITICAL - Immediate attention required',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _buildInfoRow(
                    label: 'Status',
                    value: 'Normal',
                    icon: Icons.check_circle,
                  ),
                const SizedBox(height: 24),
                // Notes
                if (report.notes != null && report.notes!.isNotEmpty) ...[
                  Text(
                    'Notes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      report.notes!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _isPreviewMode = true),
                        icon: const Icon(Icons.preview),
                        label: const Text('Preview Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadReport(report),
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
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

  Widget _buildPreviewMode(
    ReportModel report, {
    double targetMin = 2.0,
    double targetMax = 3.0,
  }) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _isPreviewMode = false),
              ),
              Expanded(
                child: Text(
                  'Report Preview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => _downloadReport(report),
              ),
            ],
          ),
        ),
        const Divider(),
        // Preview content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'INR Test Report',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // INR Value Display
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _getINRGradientColors(
                          report.inrValue,
                          isCritical: report.isCritical,
                          min: targetMin,
                          max: targetMax,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'INR',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Colors.white70,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          report.inrValue.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Test Details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _buildPreviewRow(
                          'Test Date',
                          DateFormat('MMM dd, yyyy • hh:mm a').format(
                            report.testDate,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPreviewRow(
                          'Status',
                          _getINRStatus(
                            report.inrValue,
                            isCritical: report.isCritical,
                            min: targetMin,
                            max: targetMax,
                          ),
                        ),
                        if (report.isCritical) ...[
                          const SizedBox(height: 12),
                          _buildPreviewRow(
                            'Alert',
                            'CRITICAL',
                            isAlert: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (report.notes != null && report.notes!.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text(
                      'Doctor\'s Notes',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.notes!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue[600], size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewRow(
    String label,
    String value, {
    bool isAlert = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isAlert ? Colors.red[700] : Colors.black,
              ),
        ),
      ],
    );
  }

  Future<void> _downloadReport(ReportModel report) async {
    try {
      if (report.fileUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No file URL available')),
          );
        }
        return;
      }

      debugPrint('Opening file preview: ${report.fileUrl}');
      
      final uri = Uri.parse(report.fileUrl);
      
      // Validate URL format
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid URL format: ${report.fileUrl}')),
          );
        }
        return;
      }

      // Show the file preview modal
      if (mounted) {
        await FilePreviewModal.show(
          context,
          fileUrl: report.fileUrl,
          fileName: 'INR_Report_${DateFormat('yyyyMMdd').format(report.testDate)}.pdf',
        );
      }
    } catch (e) {
      debugPrint('Error opening file preview: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  double _targetMinFrom(Map<String, dynamic> report) {
    final raw = report['target_inr_min'] ?? report['target_min'];
    if (raw is num) return raw.toDouble();
    final nested = report['medical_config'] is Map
        ? (report['medical_config'] as Map)['target_inr']
        : null;
    if (nested is Map && nested['min'] is num) {
      return (nested['min'] as num).toDouble();
    }
    return 2.0;
  }

  double _targetMaxFrom(Map<String, dynamic> report) {
    final raw = report['target_inr_max'] ?? report['target_max'];
    if (raw is num) return raw.toDouble();
    final nested = report['medical_config'] is Map
        ? (report['medical_config'] as Map)['target_inr']
        : null;
    if (nested is Map && nested['max'] is num) {
      return (nested['max'] as num).toDouble();
    }
    return 3.0;
  }

  Color _getINRColor(double inrValue, {bool isCritical = false, double min = 2.0, double max = 3.0}) {
    if (isCritical) return Colors.red;
    if (inrValue < min) return Colors.blue;
    if (inrValue > max) return Colors.red;
    return Colors.green;
  }

  List<Color> _getINRGradientColors(double inrValue, {bool isCritical = false, double min = 2.0, double max = 3.0}) {
    if (isCritical || inrValue > max) {
      return [Colors.red[400]!, Colors.red[600]!];
    }
    if (inrValue < min) {
      return [Colors.blue[400]!, Colors.blue[600]!];
    }
    return [Colors.green[400]!, Colors.green[600]!];
  }

  String _getINRStatus(double inrValue, {bool isCritical = false, double min = 2.0, double max = 3.0}) {
    if (isCritical) return 'CRITICAL';
    if (inrValue < min) return 'LOW';
    if (inrValue > max) return 'HIGH';
    return 'NORMAL';
  }
}
