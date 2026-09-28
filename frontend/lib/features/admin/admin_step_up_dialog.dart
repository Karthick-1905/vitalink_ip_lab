import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The values are held only for the pending request and are never persisted.
Future<Map<String, String>?> requestAdminStepUp(
  BuildContext context, {
  required String action,
}) async {
  final password = TextEditingController();
  final code = TextEditingController();
  try {
    return await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Verify $action'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your password and a fresh authenticator code to continue.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Authenticator code',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (password.text.isEmpty || code.text.length != 6) return;
              Navigator.pop(dialogContext, {
                'x-step-up-password': password.text,
                'x-step-up-totp': code.text,
              });
            },
            child: const Text('Verify and continue'),
          ),
        ],
      ),
    );
  } finally {
    password.dispose();
    code.dispose();
  }
}
