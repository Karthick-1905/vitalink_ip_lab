import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/common/api_error_state.dart';

/// Owns its controller until the route has actually unmounted, including exit animation.
class ReportReviewSheet extends StatefulWidget {
  final String initialNotes;
  final Future<void> Function(String notes, bool markReviewed) onSave;
  const ReportReviewSheet({
    super.key,
    required this.initialNotes,
    required this.onSave,
  });

  @override
  State<ReportReviewSheet> createState() => _ReportReviewSheetState();
}

class _ReportReviewSheetState extends State<ReportReviewSheet> {
  late final TextEditingController _notes = TextEditingController(
    text: widget.initialNotes,
  );
  bool _markReviewed = false;
  bool _saving = false;
  Object? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_notes.text.trim(), _markReviewed);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review report',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E1E5E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Read the report, add notes, and explicitly record your review.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _notes,
                enabled: !_saving,
                maxLines: 4,
                maxLength: 4000,
                decoration: InputDecoration(
                  labelText: 'Review notes',
                  hintText: 'Clinical observations and instructions',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                child: SwitchListTile(
                  title: const Text('Record report review'),
                  subtitle: const Text(
                    'Confirms you have reviewed this report',
                  ),
                  value: _markReviewed,
                  activeThumbColor: const Color(0xFF6366F1),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _markReviewed = value),
                ),
              ),
              if (_error != null)
                ApiErrorState(error: _error, onRetry: _save, compact: true),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save review'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
