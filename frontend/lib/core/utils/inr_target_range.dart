/// Shared therapeutic INR range resolution for report widgets.
///
/// Accepts top-level report fields, nested `medical_config.target_inr`, and
/// falls back to the clinical default (2.0–3.0) when bounds are missing,
/// non-finite, or inverted.
class InrTargetRange {
  const InrTargetRange({required this.min, required this.max});

  final double min;
  final double max;

  static const double defaultMin = 2.0;
  static const double defaultMax = 3.0;

  static const InrTargetRange defaults = InrTargetRange(
    min: defaultMin,
    max: defaultMax,
  );

  /// Resolve ordered finite bounds from a report-like map.
  static InrTargetRange resolve(Map<dynamic, dynamic>? source) {
    if (source == null) return defaults;

    final topMin = _asFiniteDouble(
      source['target_inr_min'] ?? source['target_min'],
    );
    final topMax = _asFiniteDouble(
      source['target_inr_max'] ?? source['target_max'],
    );
    if (topMin != null && topMax != null && topMin < topMax) {
      return InrTargetRange(min: topMin, max: topMax);
    }

    final medicalConfig = source['medical_config'];
    if (medicalConfig is Map) {
      final targetInr = medicalConfig['target_inr'];
      if (targetInr is Map) {
        final nestedMin = _asFiniteDouble(targetInr['min']);
        final nestedMax = _asFiniteDouble(targetInr['max']);
        if (nestedMin != null && nestedMax != null && nestedMin < nestedMax) {
          return InrTargetRange(min: nestedMin, max: nestedMax);
        }
      }
    }

    return defaults;
  }

  /// LOW / NORMAL / HIGH / CRITICAL classification for display.
  static String statusLabel(
    double? inr, {
    required bool isCritical,
    required double min,
    required double max,
  }) {
    if (isCritical) return 'CRITICAL';
    if (inr == null) return 'UNKNOWN';
    if (inr < min) return 'LOW';
    if (inr > max) return 'HIGH';
    return 'NORMAL';
  }

  static double? _asFiniteDouble(dynamic raw) {
    if (raw is num) {
      final value = raw.toDouble();
      return value.isFinite ? value : null;
    }
    if (raw is String) {
      final value = double.tryParse(raw);
      if (value != null && value.isFinite) return value;
    }
    return null;
  }
}
