import 'package:flutter/material.dart';

/// Keeps a mutation dialog in place while its request is running.
class AdminMutationDialog extends StatelessWidget {
  const AdminMutationDialog({
    super.key,
    required this.busy,
    required this.child,
  });

  final bool busy;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(canPop: !busy, child: child);
}

/// One-time credentials require an explicit acknowledgment before leaving.
Future<void> showAdminCredentialResult(
  BuildContext context, {
  required String title,
  required String successMessage,
  String? temporaryPassword,
}) async {
  final hasSecret = temporaryPassword?.isNotEmpty == true;
  var acknowledged = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => PopScope(
        canPop: !hasSecret || acknowledged,
        child: AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(successMessage),
                if (hasSecret) ...[
                  const SizedBox(height: 16),
                  SelectableText(temporaryPassword!),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    key: const Key('credential-acknowledgment'),
                    contentPadding: EdgeInsets.zero,
                    value: acknowledged,
                    onChanged: (value) =>
                        setState(() => acknowledged = value ?? false),
                    title: const Text(
                      'I have recorded this password for secure delivery.',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: hasSecret && !acknowledged
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    ),
  );
}
