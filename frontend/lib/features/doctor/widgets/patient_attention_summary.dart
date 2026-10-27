import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/di/theme.dart';
import 'package:frontend/features/doctor/models/patient_model.dart';

class PatientAttentionSummary extends StatelessWidget {
  final PatientModel patient;
  const PatientAttentionSummary({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final reasons = patient.attentionReasons;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (reasons.isEmpty)
          Chip(
            label: Text(
              AppCopy.text('text.no_attention_needed_9e16aee9'),
              style: TextStyle(fontSize: 12),
            ),
          ),
        for (final reason in reasons)
          Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(
              Icons.assignment_outlined,
              size: 16,
              color: AppColors.secondary,
            ),
            label: Text(
              PatientModel.reasonLabels[reason] ?? reason,
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
