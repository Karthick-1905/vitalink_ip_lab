import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/index.dart';

class PatientUpdateINRPage extends StatefulWidget {
  const PatientUpdateINRPage({super.key});

  @override
  State<PatientUpdateINRPage> createState() => _PatientUpdateINRPageState();
}

class _PatientUpdateINRPageState extends State<PatientUpdateINRPage> {
  int _currentNavIndex = 1;

  late TextEditingController _inrValueController;
  late TextEditingController _testDateController;
  late TextEditingController _notesController;

  String? _selectedFile;
  String? _fileName;
  bool _isCritical = false;

  // Target INR range
  final double _targetInrMin = 2.0;
  final double _targetInrMax = 3.0;

  @override
  void initState() {
    super.initState();
    _inrValueController = TextEditingController();
    _testDateController = TextEditingController(
      text: _formatDate(DateTime.now()),
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _inrValueController.dispose();
    _testDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PatientScaffold(
      pageTitle: 'Update INR',
      currentNavIndex: _currentNavIndex,
      onNavChanged: (index) {
        setState(() => _currentNavIndex = index);
        switch (index) {
          case 0:
            Navigator.of(context).pushReplacementNamed('/patient-home');
            break;
          case 1:
            // Already on INR page
            break;
          case 2:
            Navigator.of(context).pushReplacementNamed('/patient-take-dosage');
            break;
          case 3:
            Navigator.of(context).pushReplacementNamed('/patient-profile');
            break;
        }
      },
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card with instructions
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Target INR Range',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_targetInrMin - $_targetInrMax',
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
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 12),
                    Text(
                      'Please ensure your INR value is within the target range. If it\'s significantly outside the range, please contact your doctor immediately.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Form section
            Text(
              'Test Details',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // INR Value Input
            _buildFormField(
              label: 'INR Value *',
              child: TextField(
                controller: _inrValueController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Enter INR value (e.g., 2.5)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test Date Input
            _buildFormField(
              label: 'Date of Test *',
              child: TextField(
                controller: _testDateController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Select date',
                  suffixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                onTap: () => _selectDate(),
              ),
            ),
            const SizedBox(height: 16),

            // Critical Status Checkbox
            Card(
              elevation: 0,
              color: Colors.orange.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.orange.withOpacity(0.3)),
              ),
              child: CheckboxListTile(
                title: const Text(
                  'Is this INR value critical/urgent?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'Mark if value is significantly out of range',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                value: _isCritical,
                onChanged: (value) {
                  setState(() => _isCritical = value ?? false);
                },
                activeColor: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),

            // Notes/Instructions
            _buildFormField(
              label: 'Notes & Instructions',
              child: TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Add any notes about the test or symptoms...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Document Upload Section
            Text(
              'Test Report (Optional)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            // Upload Document Card
            GestureDetector(
              onTap: () => _showUploadOptions(),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.pink[300]!,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.pink.withOpacity(0.02),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 48,
                      color: Colors.pink[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _fileName ?? 'Upload Test Report',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.pink[400],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PDF, PNG, or JPEG (Max 10MB)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_fileName != null) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: Colors.green.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.green.withOpacity(0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'File: $_fileName',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _fileName = null;
                          _selectedFile = null;
                        }),
                        child: Icon(Icons.close, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _validateAndSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[400],
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Submit Report',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Cancel Button
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  void _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _testDateController.text = _formatDate(pickedDate);
      });
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Upload Test Report',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _simulateFileUpload('test_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
              },
              icon: const Icon(Icons.file_present),
              label: const Text('Choose File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[400],
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _simulateFileUpload('lab_report_${DateTime.now().millisecondsSinceEpoch}.jpg');
              },
              icon: const Icon(Icons.image),
              label: const Text('Take Photo'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _simulateFileUpload(String fileName) {
    setState(() {
      _fileName = fileName;
      _selectedFile = 'file_path_$fileName';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File selected: $fileName'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _validateAndSubmit() {
    // Validation
    if (_inrValueController.text.isEmpty) {
      _showError('Please enter INR value');
      return;
    }

    final inrValue = double.tryParse(_inrValueController.text);
    if (inrValue == null) {
      _showError('Please enter a valid INR value');
      return;
    }

    if (_testDateController.text.isEmpty) {
      _showError('Please select test date');
      return;
    }

    // Show submission dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are submitting:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _SubmissionDetail('INR Value', '${_inrValueController.text}'),
            _SubmissionDetail('Test Date', _testDateController.text),
            if (_isCritical)
              _SubmissionDetail('Status', 'CRITICAL - Urgent Review Needed'),
            if (_fileName != null)
              _SubmissionDetail('Document', _fileName!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processSubmission();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink[400],
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _processSubmission() {
    // Simulate submission
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: const Text(
          'Your INR report has been submitted successfully. Your doctor will review it shortly.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/patient-records');
            },
            child: const Text('Go to Records'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _SubmissionDetail extends StatelessWidget {
  final String label;
  final String value;

  const _SubmissionDetail(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
