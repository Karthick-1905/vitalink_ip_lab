import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:frontend/app/routers.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/core/utils/password_policy.dart';
import 'package:frontend/features/login/data/auth_repository.dart';
import 'package:frontend/features/login/models/login_models.dart';
import 'package:google_fonts/google_fonts.dart';

/// Self-service password change screen.
///
/// When [forced] is true (or the stored user has `must_change_password`),
/// system back navigation is blocked until the password is updated or the
/// user signs out.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, this.forced});

  /// When non-null, overrides the force mode from stored user state.
  final bool? forced;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  static const Color _primaryPurple = Color(0xFF6B5FB5);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final AuthRepository _authRepository = AppDependencies.authRepository;
  final SecureStorage _storage = SecureStorage();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  bool _signingOut = false;
  bool _forced = false;
  bool _resolvedForce = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _resolveForced();
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _resolveForced() async {
    if (widget.forced != null) {
      if (!mounted) return;
      setState(() {
        _forced = widget.forced!;
        _resolvedForce = true;
      });
      return;
    }

    try {
      final userJson = await _storage.readUser();
      final mustChange = userJson == null
          ? false
          : UserModel.fromJson(userJson).mustChangePassword;
      if (!mounted) return;
      setState(() {
        _forced = mustChange;
        _resolvedForce = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _forced = false;
        _resolvedForce = true;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _authRepository.changePassword(
        ChangePasswordRequest(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
        ),
      );
      await QueryCache.instance.clear();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppCopy.text(
              'text.password_updated_please_sign_in_with_your_new_pa_ae58a5e7',
            ),
          ),
        ),
      );
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await _authRepository.logout();
      await QueryCache.instance.clear();
    } catch (_) {
      // Local navigation must still reach login.
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) {
      return AppCopy.text('text.confirm_your_new_password_75891019');
    }
    if (value != _newController.text) {
      return AppCopy.text('text.passwords_do_not_match_a8bf4976');
    }
    return null;
  }

  String? _validateNew(String? value) {
    final policyError = PasswordPolicy.validateStrong(
      value,
      emptyMessage: AppCopy.text('text.new_password_is_required_6115dcc7'),
    );
    if (policyError != null) return policyError;
    if (value == _currentController.text) {
      return AppCopy.text(
        'text.new_password_must_differ_from_current_password_7cfb9fc3',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final errorText = _error is ApiException
        ? (_error as ApiException).message
        : _error?.toString();

    return PopScope(
      canPop: !_forced,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: const Color(0xFF1F2937),
          automaticallyImplyLeading: !_forced,
          title: Text(
            _forced
                ? AppCopy.text('text.set_a_new_password_458f610f')
                : AppCopy.text('text.change_password_87f6bf6e'),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: const Color(0xFF1F2937),
            ),
          ),
          actions: [
            if (_forced)
              TextButton(
                onPressed: _signingOut || _submitting ? null : _signOut,
                child: _signingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        AppCopy.text('text.sign_out_8b4f3c70'),
                        style: GoogleFonts.poppins(
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
          ],
        ),
        body: !_resolvedForce
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _forced
                                    ? Icons.lock_reset_rounded
                                    : Icons.lock_outline_rounded,
                                color: _primaryPurple,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _forced
                                      ? AppCopy.text(
                                          'text.for_security_replace_your_temporary_password_bef_cdf43e10',
                                        )
                                      : AppCopy.text(
                                          'text.choose_a_strong_password_after_saving_all_sessio_74d1d73f',
                                        ),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: const Color(0xFF4338CA),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _PasswordField(
                          controller: _currentController,
                          label: AppCopy.text('text.current_password_8eedf1f3'),
                          obscure: _obscureCurrent,
                          onToggle: () => setState(
                            () => _obscureCurrent = !_obscureCurrent,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return AppCopy.text(
                                'text.current_password_is_required_e1775456',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _PasswordField(
                          controller: _newController,
                          label: AppCopy.text('text.new_password_6a3aaab2'),
                          obscure: _obscureNew,
                          onToggle: () =>
                              setState(() => _obscureNew = !_obscureNew),
                          validator: _validateNew,
                          helperText: PasswordPolicy.requirementsHint,
                        ),
                        const SizedBox(height: 16),
                        _PasswordField(
                          controller: _confirmController,
                          label: AppCopy.text(
                            'text.confirm_new_password_b8965b2a',
                          ),
                          obscure: _obscureConfirm,
                          onToggle: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                          validator: _validateConfirm,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (errorText != null && errorText.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: Text(
                              errorText,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFB91C1C),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _submitting || _signingOut
                                ? null
                                : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryPurple,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _primaryPurple
                                  .withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _forced
                                        ? AppCopy.text(
                                            'text.save_and_continue_36bfe27a',
                                          )
                                        : AppCopy.text(
                                            'text.update_password_84e58cad',
                                          ),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.validator,
    this.helperText,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final FormFieldValidator<String> validator;
  final String? helperText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 15, color: const Color(0xFF1F2937)),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 2,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
        helperStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B5FB5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
