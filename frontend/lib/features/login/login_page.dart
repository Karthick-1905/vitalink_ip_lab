import 'package:frontend/core/config/app_properties.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:frontend/app/routers.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/login/data/auth_repository.dart';
import 'package:frontend/features/login/models/login_models.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static Color get _primaryPurple =>
      AppProperties.instance.color('theme.loginPrimary');
  static Color get _lightPurple =>
      AppProperties.instance.color('theme.loginLight');

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _otpFormKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final AuthRepository _authRepository = AppDependencies.authRepository;
  bool _obscurePassword = true;
  LoginOtpChallenge? _otpChallenge;
  LoginTotpChallenge? _totpChallenge;
  LoginTotpChallenge? _enrollmentChallenge;
  LoginTotpEnrollmentMaterial? _enrollmentMaterial;
  bool _isVerifyingOtp = false;
  bool _isResendingOtp = false;
  bool _isSettingUpEnrollment = false;
  Timer? _otpResendTicker;
  final ValueNotifier<int> _otpResendTick = ValueNotifier<int>(0);

  bool get _isChallengeStepActive =>
      _otpChallenge != null ||
      _totpChallenge != null ||
      _enrollmentChallenge != null;

  @override
  void dispose() {
    _otpResendTicker?.cancel();
    _otpResendTick.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _syncOtpResendTicker() {
    _otpResendTicker?.cancel();
    final challenge = _otpChallenge;
    if (challenge == null || challenge.canResendNow) return;
    _otpResendTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _otpResendTick.value++;
      if (_otpChallenge == null || _otpChallenge!.canResendNow) {
        _otpResendTicker?.cancel();
        _otpResendTicker = null;
      }
    });
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _handleSuccess(LoginResponse response) async {
    await QueryCache.instance.clear();
    if (!mounted) return;

    // Temporary / expired passwords must be replaced before any clinical UI.
    if (response.user.mustChangePassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppCopy.text('text.please_set_a_new_password_to_continue_609f84d9'),
          ),
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.changePassword,
        (previous) => false,
        arguments: true,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppCopy.text('text.login_successful_d81697f4'))),
    );

    if (response.user.isAdmin) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.adminDashboard, (previous) => false);
    } else if (response.user.isDoctor || response.user.isPatient) {
      // First-run only: show onboarding once after install + first login.
      final alreadyOnboarded = await AppDependencies.secureStorage
          .isOnboardingCompleted();
      if (!mounted) return;

      if (alreadyOnboarded) {
        final route = response.user.isDoctor
            ? AppRoutes.doctorDashboard
            : AppRoutes.patient;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(route, (previous) => false);
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.onboarding,
          (previous) => false,
          arguments: response.user.isDoctor,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppCopy.text(
              'text.login_failed_unknown_user_role_from_server_c5b5b4e3',
            ),
          ),
        ),
      );
    }
  }

  void _handleError(Object error, {bool returnToLoginForm = false}) {
    final message = error is ApiException ? error.message : error.toString();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB3261E),
        ),
      );

    // Invalid credentials and other auth failures should not leave a
    // "Session expired / Back to login" card on this page — toast only.
    if (returnToLoginForm &&
        error is ApiException &&
        _isChallengeStepActive &&
        _shouldLeaveChallenge(error)) {
      _returnToLogin();
    }
  }

  bool _shouldLeaveChallenge(ApiException error) {
    if (error.kind == ApiErrorKind.gone ||
        error.kind == ApiErrorKind.locked ||
        error.kind == ApiErrorKind.notFound ||
        error.statusCode == 404) {
      return true;
    }
    // Wrong authenticator codes are 401 "Invalid TOTP code" and must stay on
    // the enrollment/verify form. Lockout and other 401s return to password.
    if (error.kind == ApiErrorKind.unauthorized) {
      return !error.isInvalidTotpCode;
    }
    return false;
  }

  void _submit(MutationResult<LoginResult, LoginRequest> mutation) {
    if (!_formKey.currentState!.validate()) return;

    final request = LoginRequest(
      loginId: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    mutation.mutate(request);
  }

  Future<void> _verifyOtp() async {
    final challenge = _otpChallenge;
    if (challenge == null || !_otpFormKey.currentState!.validate()) return;
    if (!challenge.canVerifyNow) {
      _handleError(
        ApiException(
          challenge.isExpired
              ? 'This code has expired. Return to login and try again.'
              : 'No verification attempts remaining.',
          kind: ApiErrorKind.badRequest,
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      final response = await _authRepository.verifyLoginOtp(
        VerifyLoginOtpRequest(
          challengeId: challenge.challengeId,
          code: _otpController.text.trim(),
        ),
      );
      await _handleSuccess(response);
    } catch (error) {
      if (!mounted) return;
      _handleError(error, returnToLoginForm: true);
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
      }
    }
  }

  Future<void> _verifyTotp() async {
    final challenge = _totpChallenge;
    if (challenge == null || !_otpFormKey.currentState!.validate()) return;

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      final response = await _authRepository.verifyLoginTotp(
        VerifyLoginTotpRequest(
          challengeId: challenge.challengeId,
          code: _otpController.text.trim(),
        ),
      );
      await _handleSuccess(response);
    } catch (error) {
      if (!mounted) return;
      _handleError(error, returnToLoginForm: true);
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    final challenge = _otpChallenge;
    if (challenge == null || _isResendingOtp) return;
    if (!challenge.canResendNow) {
      final message = challenge.isExpired
          ? 'This code has expired. Return to login and try again.'
          : !challenge.hasResendsRemaining
          ? 'Resend limit reached.'
          : 'Please wait before requesting another code.';
      _handleError(ApiException(message, kind: ApiErrorKind.rateLimited));
      return;
    }

    setState(() {
      _isResendingOtp = true;
    });

    try {
      final updatedChallenge = await _authRepository.resendLoginOtp(
        ResendLoginOtpRequest(challengeId: challenge.challengeId),
      );
      if (!mounted) return;
      setState(() {
        _otpChallenge = updatedChallenge;
        _otpController.clear();
      });
      _syncOtpResendTicker();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppCopy.text(
              'text.otp_sent_to_value1_1bc024e3',
              arguments: {'value1': (updatedChallenge.maskedPhone).toString()},
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _handleError(error, returnToLoginForm: true);
    } finally {
      if (mounted) {
        setState(() {
          _isResendingOtp = false;
        });
      }
    }
  }

  Future<void> _setupEnrollment() async {
    final challenge = _enrollmentChallenge;
    if (challenge == null || _isSettingUpEnrollment) return;

    setState(() {
      _isSettingUpEnrollment = true;
    });

    try {
      final material = await _authRepository.setupLoginTotpEnrollment(
        EnrollAdminTotpSetupRequest(challengeId: challenge.challengeId),
      );
      if (!mounted) return;
      setState(() {
        _enrollmentMaterial = material;
      });
    } catch (error) {
      if (!mounted) return;
      _handleError(error, returnToLoginForm: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSettingUpEnrollment = false;
        });
      }
    }
  }

  Future<void> _activateEnrollment() async {
    final challenge = _enrollmentChallenge;
    if (challenge == null || !_otpFormKey.currentState!.validate()) return;
    if (!challenge.canVerifyNow) {
      _handleError(
        ApiException(
          challenge.isExpired
              ? 'This enrollment step expired. Return to login and try again.'
              : 'No verification attempts remaining.',
          kind: ApiErrorKind.badRequest,
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      final response = await _authRepository.activateLoginTotpEnrollment(
        EnrollAdminTotpActivateRequest(
          challengeId: challenge.challengeId,
          code: _otpController.text.trim(),
        ),
      );
      await _handleSuccess(response);
    } catch (error) {
      if (!mounted) return;
      _handleError(error, returnToLoginForm: true);
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
      }
    }
  }

  Future<void> _copyEnrollmentSecret() async {
    final secret = _enrollmentMaterial?.secret.trim() ?? '';
    if (secret.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: secret));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppCopy.text('text.setup_key_copied_f651cae7'))),
    );
  }

  void _returnToLogin() {
    _otpResendTicker?.cancel();
    _otpResendTicker = null;
    setState(() {
      _otpChallenge = null;
      _totpChallenge = null;
      _enrollmentChallenge = null;
      _enrollmentMaterial = null;
      _isSettingUpEnrollment = false;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: UseMutation<LoginResult, LoginRequest>(
        options: MutationOptions<LoginResult, LoginRequest>(
          mutationFn: _authRepository.login,
          onSuccess: (data, variables) async {
            if (!mounted) return;
            if (data.isOtpRequired) {
              setState(() {
                _otpChallenge = data.otpChallenge;
                _totpChallenge = null;
                _enrollmentChallenge = null;
                _enrollmentMaterial = null;
                _otpController.clear();
              });
              _syncOtpResendTicker();
              return;
            }

            if (data.isTotpRequired) {
              setState(() {
                _totpChallenge = data.totpChallenge;
                _otpChallenge = null;
                _enrollmentChallenge = null;
                _enrollmentMaterial = null;
                _otpController.clear();
              });
              return;
            }

            if (data.isEnrollmentRequired) {
              setState(() {
                _enrollmentChallenge = data.enrollmentChallenge;
                _otpChallenge = null;
                _totpChallenge = null;
                _enrollmentMaterial = null;
                _otpController.clear();
              });
              await _setupEnrollment();
              return;
            }

            final response = data.response;
            if (response != null) {
              await _handleSuccess(response);
            }
          },
          onError: (error, variables) {
            if (!mounted) return;
            _handleError(error);
          },
        ),
        builder: (context, mutation) {
          return SizedBox(
            width: screenWidth,
            height: screenHeight,
            child: Stack(
              children: [
                // Top-left purple curved shape
                Positioned(
                  top: 0,
                  left: 0,
                  child: CustomPaint(
                    size: Size(screenWidth * 0.65, screenHeight * 0.22),
                    painter: _TopLeftCurvePainter(),
                  ),
                ),

                // Bottom-right purple curved shape
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CustomPaint(
                    size: Size(screenWidth * 0.65, screenHeight * 0.15),
                    painter: _BottomRightCurvePainter(),
                  ),
                ),

                // Main content
                SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            screenHeight -
                            MediaQuery.of(context).padding.top -
                            MediaQuery.of(context).padding.bottom,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            SizedBox(height: screenHeight * 0.08),

                            // Welcome text with nice font
                            Text(
                              AppCopy.text('text.welcome_back_cb897846'),
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2D3142),
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.03),

                            // Doctor-patient illustration
                            SizedBox(
                              height: screenHeight * 0.25,
                              child: PropertyImage(
                                'asset.loginIllustration',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: screenHeight * 0.25,
                                    decoration: BoxDecoration(
                                      color: _lightPurple.withAlpha(25),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.medical_services_outlined,
                                        size: 80,
                                        color: _primaryPurple,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.04),

                            if (_otpChallenge == null &&
                                _totpChallenge == null &&
                                _enrollmentChallenge == null)
                              _buildLoginForm(mutation)
                            else if (_otpChallenge != null)
                              ValueListenableBuilder<int>(
                                valueListenable: _otpResendTick,
                                builder: (context, _, _) =>
                                    _buildOtpForm(_otpChallenge!),
                              )
                            else if (_totpChallenge != null)
                              _buildTotpForm(_totpChallenge!)
                            else if (_enrollmentChallenge != null)
                              _buildEnrollmentForm(_enrollmentChallenge!),

                            SizedBox(height: screenHeight * 0.04),

                            // Logos (opaque PNGs — transparent crests vanished on
                            // some Android GPUs / dark launcher themes)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 45,
                                  child: PropertyImage(
                                    'asset.hospitalLogo',
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.medium,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.account_balance_outlined,
                                      size: 40,
                                      color: _primaryPurple,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                SizedBox(
                                  height: 45,
                                  child: PropertyImage(
                                    'asset.instituteLogo',
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.medium,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.local_hospital_outlined,
                                      size: 40,
                                      color: _primaryPurple,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: screenHeight * 0.06),

                            // Forgot password link
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: Color(0xFFE5E5E5),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    AppCopy.text(
                                      'text.forgot_your_password_contact_your_administrator__fda6db8a',
                                    ),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).padding.bottom + 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        style: GoogleFonts.poppins(fontSize: 15),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 15),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(icon, color: Colors.grey[500], size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          errorStyle: GoogleFonts.poppins(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildLoginForm(MutationResult<LoginResult, LoginRequest> mutation) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _emailController,
            hintText: AppCopy.text('text.username_1c08d4d9'),
            icon: Icons.person_outline,
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) {
                return AppCopy.text('text.username_is_required_6d2b33f8');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _passwordController,
            hintText: AppCopy.text('text.password_2cc30838'),
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              onPressed: _togglePasswordVisibility,
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey[500],
                size: 22,
              ),
            ),
            validator: (value) {
              final v = value ?? '';
              if (v.isEmpty) {
                return AppCopy.text('text.password_is_required_dd9a7069');
              }
              if (v.length < 6) {
                return AppCopy.text(
                  'text.must_be_at_least_6_characters_47e98c07',
                );
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          _buildPrimaryButton(
            label: AppCopy.text('text.login_acd20e52'),
            isLoading: mutation.isLoading,
            onPressed: mutation.isLoading ? null : () => _submit(mutation),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpForm(LoginOtpChallenge challenge) {
    final attempts = challenge.attemptsRemaining;
    final resendCount = challenge.resendCount;
    final maxResends = challenge.maxResends;
    final cooldownSeconds = challenge.resendCooldownSecondsRemaining;
    final canResend = !_isResendingOtp && challenge.canResendNow;
    final canVerify = !_isVerifyingOtp && challenge.canVerifyNow;
    final statusMessage = challenge.isExpired
        ? 'This code has expired. Return to login and try again.'
        : !challenge.hasAttemptsRemaining
        ? 'No verification attempts remaining.'
        : !challenge.hasResendsRemaining
        ? 'Resend limit reached.'
        : cooldownSeconds != null && cooldownSeconds > 0
        ? 'Resend available in ${cooldownSeconds}s'
        : null;
    final resendDetail = resendCount != null && maxResends != null
        ? 'Resends used: $resendCount of $maxResends'
        : null;
    final resendLabel = _isResendingOtp
        ? 'Sending'
        : !challenge.hasResendsRemaining
        ? 'Resend limit reached'
        : cooldownSeconds != null && cooldownSeconds > 0
        ? 'Resend in ${cooldownSeconds}s'
        : 'Resend OTP';

    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _lightPurple.withAlpha(22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: _primaryPurple,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppCopy.text('text.verify_your_phone_56e7aa4f'),
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2D3142),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppCopy.text(
                              'text.enter_the_otp_sent_to_value1_90c726e6',
                              arguments: {
                                'value1': (challenge.maskedPhone).toString(),
                              },
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              height: 1.45,
                              color: const Color(0xFF4B5164),
                            ),
                          ),
                          if (attempts != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              AppCopy.text(
                                'text.value1_attempts_remaining_500126b5',
                                arguments: {'value1': (attempts).toString()},
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF5D6475),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _otpController,
            hintText: AppCopy.text('text.otp_code_e5c04063'),
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) {
                return AppCopy.text('text.otp_code_is_required_ec6eb2e6');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildPrimaryButton(
            label: AppCopy.text('text.verify_otp_21f14245'),
            isLoading: _isVerifyingOtp,
            onPressed: canVerify ? _verifyOtp : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: canResend ? _resendOtp : null,
                  icon: _isResendingOtp
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_outlined, size: 18),
                  label: Text(resendLabel),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: _isVerifyingOtp || _isResendingOtp
                      ? null
                      : _returnToLogin,
                  icon: const Icon(Icons.arrow_back_outlined, size: 18),
                  label: Text(AppCopy.text('text.back_c2954bc2')),
                ),
              ),
            ],
          ),
          if (statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                statusMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF5D6475),
                ),
              ),
            ),
          if (resendDetail != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                resendDetail,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF5D6475),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotpForm(LoginTotpChallenge challenge) {
    final attempts = challenge.attemptsRemaining;

    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _lightPurple.withAlpha(22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  color: _primaryPurple,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppCopy.text(
                          'text.authenticator_verification_873e6003',
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2D3142),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppCopy.text(
                          'text.enter_the_6_digit_code_from_your_authenticator_a_7feb1b8c',
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          height: 1.45,
                          color: const Color(0xFF4B5164),
                        ),
                      ),
                      if (attempts != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          AppCopy.text(
                            'text.value1_attempts_remaining_500126b5',
                            arguments: {'value1': (attempts).toString()},
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF5D6475),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _otpController,
            hintText: AppCopy.text('text.authenticator_code_fcb600fd'),
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) {
                return AppCopy.text(
                  'text.authenticator_code_is_required_452a11c',
                );
              }
              if (v.length != 6) {
                return AppCopy.text('text.enter_the_6_digit_code_fdf4a3a5');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildPrimaryButton(
            label: AppCopy.text('text.verify_831765a4'),
            isLoading: _isVerifyingOtp,
            onPressed: _isVerifyingOtp ? null : _verifyTotp,
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _isVerifyingOtp ? null : _returnToLogin,
            icon: const Icon(Icons.arrow_back_outlined, size: 18),
            label: Text(AppCopy.text('text.back_c2954bc2')),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollmentForm(LoginTotpChallenge challenge) {
    final attempts = challenge.attemptsRemaining;
    final material = _enrollmentMaterial;
    final canActivate =
        !_isVerifyingOtp &&
        !_isSettingUpEnrollment &&
        material != null &&
        challenge.canVerifyNow;
    final statusMessage = challenge.isExpired
        ? 'This enrollment step expired. Return to login and try again.'
        : !challenge.hasAttemptsRemaining
        ? 'No verification attempts remaining.'
        : null;

    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _lightPurple.withAlpha(22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.qr_code_2_outlined, color: _primaryPurple, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppCopy.text('text.set_up_authenticator_663ba1cb'),
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2D3142),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppCopy.text(
                          'text.your_administrator_account_requires_an_authentic_480ccfde',
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          height: 1.45,
                          color: const Color(0xFF4B5164),
                        ),
                      ),
                      if (attempts != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          AppCopy.text(
                            'text.value1_attempts_remaining_500126b5',
                            arguments: {'value1': (attempts).toString()},
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF5D6475),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_isSettingUpEnrollment && material == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (material == null)
            _buildPrimaryButton(
              label: AppCopy.text('text.load_setup_36cd3efc'),
              isLoading: _isSettingUpEnrollment,
              onPressed: _isSettingUpEnrollment ? null : _setupEnrollment,
            )
          else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: material.otpauthUrl,
                  version: QrVersions.auto,
                  size: 196,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                  semanticsLabel: 'Authenticator app setup QR code',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppCopy.text(
                'text.if_you_cannot_scan_the_code_enter_this_setup_key_4dfa3f25',
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                height: 1.4,
                color: const Color(0xFF5D6475),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      material.secret,
                      style: GoogleFonts.robotoMono(
                        fontSize: 13,
                        letterSpacing: 0.6,
                        color: const Color(0xFF2D3142),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _copyEnrollmentSecret,
                    tooltip: AppCopy.text('text.copy_setup_key_7c660c72'),
                    icon: const Icon(Icons.copy_outlined, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _otpController,
              hintText: AppCopy.text('text.authenticator_code_fcb600fd'),
              icon: Icons.pin_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) {
                  return AppCopy.text(
                    'text.authenticator_code_is_required_452a11c',
                  );
                }
                if (v.length != 6) {
                  return AppCopy.text('text.enter_the_6_digit_code_fdf4a3a5');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildPrimaryButton(
              label: AppCopy.text('text.activate_and_sign_in_a1d6d80d'),
              isLoading: _isVerifyingOtp,
              onPressed: canActivate ? _activateEnrollment : null,
            ),
          ],
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _isVerifyingOtp || _isSettingUpEnrollment
                ? null
                : _returnToLogin,
            icon: const Icon(Icons.arrow_back_outlined, size: 18),
            label: Text(AppCopy.text('text.back_c2954bc2')),
          ),
          if (statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                statusMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF5D6475),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }
}

// Custom painter for top-left curved shape
class _TopLeftCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6B5FB5), Color(0xFF9B8FD9)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.3,
      size.width * 0.5,
      size.height * 0.7,
    );
    path.quadraticBezierTo(
      size.width * 0.15,
      size.height * 1.1,
      0,
      size.height * 0.85,
    );
    path.lineTo(0, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for bottom-right curved shape
class _BottomRightCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF9B8FD9), Color(0xFF6B5FB5)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    path.moveTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.quadraticBezierTo(
      size.width * 0.15,
      size.height * 0.7,
      size.width * 0.5,
      size.height * 0.3,
    );
    path.quadraticBezierTo(
      size.width * 0.85,
      -size.height * 0.1,
      size.width,
      size.height * 0.15,
    );
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
