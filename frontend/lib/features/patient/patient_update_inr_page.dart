import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/index.dart';
import 'package:frontend/app/routers.dart';
import 'package:frontend/services/patient_service.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

class PatientUpdateINRPage extends StatefulWidget {
  const PatientUpdateINRPage({super.key});

  @override
  State<PatientUpdateINRPage> createState() => _PatientUpdateINRPageState();
}

class _PatientUpdateINRPageState extends State<PatientUpdateINRPage> {
  final int _currentNavIndex = 1;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _inrValueController = TextEditingController();
  final TextEditingController _testDateController = TextEditingController();
  
  PlatformFile? _selectedFile;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _testDateController.text = DateFormat('dd-MM-yyyy').format(_selectedDate);
  }

  @override
  void dispose() {
    _inrValueController.dispose();
    _testDateController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF0084FF),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black87,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _testDateController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return UseMutation<void, Map<String, dynamic>>(
      options: MutationOptions<void, Map<String, dynamic>>(
        mutationFn: (variables) => PatientService.submitINRReport(
          inrValue: variables['inr_value'],
          testDate: variables['test_date'],
          fileBytes: variables['file_bytes'],
          fileName: variables['file_name'],
        ),
        onSuccess: (data, variables) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted successfully!'), backgroundColor: Colors.green),
          );
          // Invalidate queries to refetch updated data
          final queryClient = QueryClientProvider.of(context);
          queryClient.invalidateQueries(['patient', 'home_data']);
          queryClient.invalidateQueries(['patient', 'records_full']);
          queryClient.invalidateQueries(['patient', 'profile_full']);
          
          Navigator.of(context).pushReplacementNamed(AppRoutes.patientHealthReports);
        },
        onError: (error, variables) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${error.toString()}'), backgroundColor: Colors.red),
          );
        },
      ),
      builder: (context, mutation) {
        return PatientScaffold(
          pageTitle: 'Update INR',
          currentNavIndex: _currentNavIndex,
          onNavChanged: (index) {
            if (index == _currentNavIndex) return;
            switch (index) {
              case 0: Navigator.of(context).pushReplacementNamed(AppRoutes.patient); break;
              case 1: break;
              case 2: Navigator.of(context).pushReplacementNamed(AppRoutes.patientTakeDosage); break;
              case 3: Navigator.of(context).pushReplacementNamed(AppRoutes.patientHealthReports); break;
              case 4: Navigator.of(context).pushReplacementNamed(AppRoutes.patientProfile); break;
            }
          },
          bodyDecoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFC8B5E1), Color(0xFFF8C7D7)],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('INR Value :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _inrValueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecoration('Enter INR value'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter INR value';
                        if (double.tryParse(value) == null) return 'Please enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    const Text('Date of Test :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _testDateController,
                      readOnly: true,
                      onTap: () => _showDatePicker(context),
                      decoration: _inputDecoration('dd-mm-yyyy --:--').copyWith(
                        suffixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: Icon(Icons.calendar_month, color: Colors.black54),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text('Upload Document:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickFile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0E5F5).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, color: Colors.black54, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedFile?.name ?? 'Select a file',
                                style: TextStyle(
                                  color: _selectedFile != null ? Colors.black87 : Colors.black54,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: mutation.isLoading ? null : () {
                          if (_formKey.currentState!.validate()) {
                            mutation.mutate({
                              'inr_value': _inrValueController.text,
                              'test_date': _testDateController.text,
                              'file_bytes': _selectedFile?.bytes,
                              'file_name': _selectedFile?.name,
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0084FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: mutation.isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Submit INR Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black45, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0084FF), width: 1.5)),
    );
  }
}
