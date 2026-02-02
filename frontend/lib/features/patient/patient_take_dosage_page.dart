import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/index.dart';
import 'package:frontend/core/widgets/patient/patient_dosage_widgets.dart';
import 'package:frontend/app/routers.dart';
import 'package:frontend/services/patient_service.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';

class PatientTakeDosagePage extends StatefulWidget {
  const PatientTakeDosagePage({super.key});

  @override
  State<PatientTakeDosagePage> createState() => _PatientTakeDosagePageState();
}

class _PatientTakeDosagePageState extends State<PatientTakeDosagePage> {
  final int _currentNavIndex = 2;
  int _currentPage = 1;
  final int _itemsPerPage = 8;

  @override
  Widget build(BuildContext context) {
    return UseQuery<Map<String, dynamic>>(
      options: QueryOptions<Map<String, dynamic>>(
        queryKey: const ['patient', 'missed_doses'],
        queryFn: () async {
          return await PatientService.getMissedDoses();
        },
      ),
      builder: (context, query) {
        if (query.isLoading) {
          return const PatientScaffold(
            pageTitle: 'Dosage Management',
            currentNavIndex: 2,
            onNavChanged: _dummyOnNavChanged,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (query.isError) {
          return PatientScaffold(
            pageTitle: 'Dosage Management',
            currentNavIndex: 2,
            onNavChanged: (index) => _handleNav(index),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${query.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => query.refetch(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!query.hasData) {
          return const PatientScaffold(
            pageTitle: 'Dosage Management',
            currentNavIndex: 2,
            onNavChanged: _dummyOnNavChanged,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = query.data!;
        final recentDoses = data['recent_missed_doses'] as List<dynamic>;
        final remainingDoses = data['missed_doses'] as List<dynamic>;

        return UseMutation<void, Map<String, dynamic>>(
          options: MutationOptions<void, Map<String, dynamic>>(
            mutationFn: (variables) => PatientService.markDoseAsTaken(
              date: variables['date'],
              dose: variables['dose'],
            ),
            onSuccess: (data, variables) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dose marked as taken!'),
                  backgroundColor: Colors.green,
                ),
              );
              // Invalidate queries to refetch updated data
              final queryClient = QueryClientProvider.of(context);
              queryClient.invalidateQueries(['patient', 'home_data']);
              queryClient.invalidateQueries(['patient', 'records_full']);
              query.refetch();
            },
            onError: (error, variables) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${error.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            },
          ),
          builder: (context, mutation) {
            return PatientScaffold(
              pageTitle: 'Dosage Management',
              currentNavIndex: _currentNavIndex,
              bodyDecoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFC8B5E1), Color(0xFFF8C7D7)],
                ),
              ),
              onNavChanged: (index) => _handleNav(index),
              body: RefreshIndicator(
                onRefresh: () async => query.refetch(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Recent Missed Doses Section
                        DosageSection(
                          title: 'Missed Doses',
                          subtitle: 'Below are the missed doses for the last 7 days.\nClick on the date to mark it as taken.',
                          children: [
                            if (recentDoses.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    'No missed doses in the last 7 days',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              )
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 2.5,
                                ),
                                itemCount: recentDoses.length,
                                itemBuilder: (context, index) {
                                  final date = recentDoses[index] as String;
                                  return DosageDateCard(
                                    date: date,
                                    onTap: () => _showMarkAsTakenDialog(date, mutation),
                                  );
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Remaining Missed Doses Section
                        DosageSection(
                          title: 'Remaining Missed Doses',
                          children: [
                            if (remainingDoses.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    'No remaining missed doses',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              )
                            else
                              _buildPaginatedRemainingDoses(remainingDoses),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaginatedRemainingDoses(List<dynamic> doses) {
    final totalPages = (doses.length / _itemsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, doses.length);
    final currentPageDoses = doses.sublist(startIndex, endIndex);

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 3.5,
          ),
          itemCount: currentPageDoses.length,
          itemBuilder: (context, index) {
            final date = currentPageDoses[index] as String;
            return RemainingDoseCard(date: date);
          },
        ),
        if (totalPages > 1) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF87CEEB),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Previous'),
              ),
              const SizedBox(width: 16),
              Text(
                'Page $_currentPage of $totalPages',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0084FF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showMarkAsTakenDialog(
    String date,
    MutationResult<void, Map<String, dynamic>> mutation,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Mark Dose as Taken',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to mark this dose as taken?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: mutation.isLoading
                ? null
                : () {
                    Navigator.pop(context);
                    mutation.mutate({
                      'date': date,
                      'dose': 5.0, // Default dose value
                    });
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: mutation.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  static void _dummyOnNavChanged(int index) {}

  void _handleNav(int index) {
    if (index == _currentNavIndex) return;
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacementNamed(AppRoutes.patient);
        break;
      case 1:
        Navigator.of(context).pushReplacementNamed(AppRoutes.patientUpdateINR);
        break;
      case 2:
        break;
      case 3:
        Navigator.of(context).pushReplacementNamed(AppRoutes.patientHealthReports);
        break;
      case 4:
        Navigator.of(context).pushReplacementNamed(AppRoutes.patientProfile);
        break;
    }
  }
}
