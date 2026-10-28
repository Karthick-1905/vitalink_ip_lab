import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/query/doctor_query_keys.dart';
import 'package:frontend/features/doctor/data/doctor_repository.dart';
import 'package:frontend/features/doctor/models/doctor_profile_model.dart';
import 'package:frontend/core/widgets/index.dart';

class DoctorProfilePage extends StatelessWidget {
  const DoctorProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final DoctorRepository repository = AppDependencies.doctorRepository;

    return UseQuery<DoctorProfileModel>(
      options: QueryOptions<DoctorProfileModel>(
        queryKey: DoctorQueryKeys.profile(),
        queryFn: repository.getDoctorProfile,
      ),
      builder: (context, query) {
        // PageSkeleton owns its own SingleChildScrollView — never nest it
        // inside another vertical scrollable (unbounded height assertion).
        if (query.isLoading) {
          return PageSkeleton(
            cardCount: 3,
            showHeader: false,
            padding: PortalLayout.doctorShellPadding,
          );
        }

        return SingleChildScrollView(
          padding: PortalLayout.doctorShellPadding,
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (query.isError)
                ApiErrorState(
                  error: query.error,
                  onRetry: () => query.refetch(),
                  compact: true,
                  title: AppCopy.text('text.could_not_load_profile_358adeb4'),
                ),
              if (query.isSuccess && query.data != null)
                DoctorProfileContent(
                  profile: query.data!,
                  onProfileUpdated: () => query.refetch(),
                ),
            ],
          ),
        );
      },
    );
  }
}
