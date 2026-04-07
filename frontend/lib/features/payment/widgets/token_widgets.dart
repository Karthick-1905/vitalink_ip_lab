import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Token balance display widget
class TokenBalanceWidget extends ConsumerWidget {
  final bool showLabel;
  final double fontSize;
  final MainAxisAlignment alignment;

  const TokenBalanceWidget({
    Key? key,
    this.showLabel = true,
    this.fontSize = 16,
    this.alignment = MainAxisAlignment.center,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        if (showLabel) Text('Tokens:', style: TextStyle(fontSize: fontSize - 2)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            border: Border.all(
              color: Colors.green,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Loading...',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget to show token requirement before action
class TokenRequirementWidget extends StatelessWidget {
  final String feature;
  final int requiredTokens;
  final int availableTokens;
  final bool hasEnough;

  const TokenRequirementWidget({
    Key? key,
    required this.feature,
    required this.requiredTokens,
    required this.availableTokens,
    required this.hasEnough,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasEnough ? Colors.green.shade50 : Colors.red.shade50,
        border: Border.all(
          color: hasEnough ? Colors.green : Colors.red,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            hasEnough ? Icons.check_circle : Icons.warning,
            color: hasEnough ? Colors.green : Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: hasEnough ? Colors.green.shade900 : Colors.red.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Required: $requiredTokens | Available: $availableTokens',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasEnough ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to display all feature costs
class FeatureCostsDisplayWidget extends ConsumerWidget {
  const FeatureCostsDisplayWidget({Key? key}) : super(key: key);

  static const Map<String, int> featureCosts = {
    'DOSAGE_LOG': 5,
    'HEALTH_LOG_UPDATE': 10,
    'PROFILE_UPDATE': 15,
    'REPORT_UPLOAD': 25,
    'DOCTOR_CONSULTATION': 100,
    'VIDEO_CALL': 50,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Feature Costs',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: featureCosts.entries.map((entry) {
              return ListTile(
                leading: Icon(_getFeatureIcon(entry.key)),
                title: Text(_formatFeatureName(entry.key)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${entry.value} tokens',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getFeatureIcon(String feature) {
    switch (feature) {
      case 'DOSAGE_LOG':
        return Icons.medication;
      case 'HEALTH_LOG_UPDATE':
        return Icons.health_and_safety;
      case 'PROFILE_UPDATE':
        return Icons.person;
      case 'REPORT_UPLOAD':
        return Icons.upload_file;
      case 'DOCTOR_CONSULTATION':
        return Icons.local_hospital;
      case 'VIDEO_CALL':
        return Icons.videocam;
      default:
        return Icons.info;
    }
  }

  String _formatFeatureName(String feature) {
    return feature
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}

/// Shimmer loading placeholder
class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;

  const ShimmerLoading({
    Key? key,
    required this.width,
    required this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Token progress bar showing available tokens with visual indicator
class TokenProgressBarWidget extends StatelessWidget {
  final int currentTokens;
  final int maxTokens;
  final bool showPercentage;
  final double height;

  const TokenProgressBarWidget({
    Key? key,
    required this.currentTokens,
    this.maxTokens = 200,
    this.showPercentage = true,
    this.height = 12,
  }) : super(key: key);

  Color _getColorForPercentage(double percentage) {
    if (percentage >= 75) {
      return Colors.green;
    } else if (percentage >= 50) {
      return Colors.amber;
    } else if (percentage >= 25) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double percentage = (currentTokens / maxTokens).clamp(0, 1);
    final color = _getColorForPercentage(percentage * 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Token Wallet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              '$currentTokens / $maxTokens',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: height,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        if (showPercentage)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${(percentage * 100).toStringAsFixed(1)}% available',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
      ],
    );
  }
}
