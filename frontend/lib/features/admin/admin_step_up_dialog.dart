import 'package:frontend/core/config/app_properties.dart';
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
        title: Text(
          AppCopy.text(
            'text.verify_value1_533023e4',
            arguments: {'value1': (action).toString()},
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppCopy.text(
                  'text.enter_your_password_and_a_fresh_authenticator_co_72b3655f',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: AppCopy.text('text.current_password_8eedf1f3'),
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
                decoration: InputDecoration(
                  labelText: AppCopy.text('text.authenticator_code_fcb600fd'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppCopy.text('text.cancel_35afca3b')),
          ),
          FilledButton(
            onPressed: () {
              if (password.text.isEmpty || code.text.length != 6) return;
              Navigator.pop(dialogContext, {
                'x-step-up-password': password.text,
                'x-step-up-totp': code.text,
              });
            },
            child: Text(AppCopy.text('text.verify_and_continue_33c367ce')),
          ),
        ],
      ),
    );
  } finally {
    password.dispose();
    code.dispose();
  }
}
