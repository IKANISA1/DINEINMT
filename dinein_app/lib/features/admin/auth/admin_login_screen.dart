import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/config/country_runtime.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/whatsapp_otp_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _error;
  String? _info;
  String _step = 'phone'; // 'phone' or 'otp'
  WhatsAppOtpChallenge? _challenge;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _fadeController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  // ─── Cooldown ───

  void _startCooldown() {
    _cooldownSeconds = 45;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) timer.cancel();
      });
    });
  }

  bool get _isCoolingDown => _cooldownSeconds > 0;

  String get _countryCode => CountryRuntime.config.defaultCountryCode;

  String get _dialCode => CountryRuntime.config.countryDialCode;

  int get _expectedPhoneLength =>
      CountryRuntime.config.country.code == 'RW' ? 10 : 8;

  String get _localPhone => normalizePhoneLocalInput(
    _phoneController.text,
    countryCode: _countryCode,
    maxDigits: _expectedPhoneLength,
  );

  String get _fullPhone => _localPhone.isEmpty ? '' : '$_dialCode$_localPhone';

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  bool get _canSendOtp =>
      !_isLoading &&
      !_isCoolingDown &&
      isValidPhoneLocalInput(
        _phoneController.text,
        countryCode: _countryCode,
        expectedLength: _expectedPhoneLength,
      );

  String _entryReturnPath(BuildContext context) {
    final candidate = GoRouterState.of(
      context,
    ).uri.queryParameters[AppRouteParams.returnTo];
    switch (candidate) {
      case AppRoutePaths.guestSettings:
      case AppRoutePaths.venueSettings:
      case AppRoutePaths.adminSettings:
        return candidate!;
      default:
        return AppRoutePaths.splash;
    }
  }

  bool _requiresSupportContact(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('not registered for admin');
  }

  Future<void> _showAdminSupportDialog() {
    return showAccessSupportDialog(
      context,
      title: 'Admin Access Not Found',
      message:
          'This WhatsApp number is not registered for admin access. Contact support to activate or recover admin access.',
    );
  }

  // ─── Send OTP ───

  Future<void> _sendOtp() async {
    if (_isCoolingDown) return;
    if (!isValidPhoneLocalInput(
      _phoneController.text,
      countryCode: _countryCode,
      expectedLength: _expectedPhoneLength,
    )) {
      setState(() {
        _error =
            'Enter your $_expectedPhoneLength-digit ${CountryRuntime.config.country.label} phone number.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });

    try {
      final challenge = await WhatsAppOtpService.instance.sendOtp(
        _fullPhone,
        appScope: 'admin',
      );
      if (!mounted) return;
      _startCooldown();

      // Animate transition to OTP step
      await _fadeController.reverse();
      if (!mounted) return;

      setState(() {
        _challenge = challenge;
        _step = 'otp';
        _isLoading = false;
        _info =
            !kReleaseMode && challenge.usesMock && challenge.debugCode != null
            ? 'Dev code: ${challenge.debugCode}'
            : null;
      });

      _fadeController.forward();

      // Focus the first OTP field
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocusNodes[0].requestFocus();
      });
    } catch (error) {
      if (!mounted) return;
      if (_requiresSupportContact(error)) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
        await _showAdminSupportDialog();
        return;
      }

      final raw = error.toString();
      final message = raw.contains('Too many')
          ? 'Too many requests. Wait a few minutes.'
          : 'Could not send code. Check the number and retry.';
      setState(() {
        _isLoading = false;
        _error = message;
      });
    }
  }

  // ─── Verify OTP ───

  Future<void> _verifyOtp() async {
    final challenge = _challenge;
    final code = _otpCode;
    if (challenge == null || code.length != 6) {
      setState(() {
        _error = 'Enter the full 6-digit code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });

    try {
      final result = await WhatsAppOtpService.instance.verifyOtpDetailed(
        phone: _fullPhone,
        verificationId: challenge.verificationId,
        code: code,
        appScope: 'admin',
      );

      if (!result.verified) {
        throw Exception(_messageForReason(result.reason));
      }

      final adminSession = result.adminSession;
      if (adminSession == null) {
        throw Exception('Verified, but no console session was issued.');
      }

      await AuthRepository.instance.saveAdminSession(adminSession);

      if (!mounted) return;
      context.goNamed(AppRouteNames.adminOverview);
    } catch (error) {
      if (!mounted) return;
      if (_requiresSupportContact(error)) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
        await _showAdminSupportDialog();
        return;
      }

      String message;
      if (error is Exception) {
        final raw = error.toString();
        if (raw.contains('Exception: ')) {
          message = raw.replaceFirst(RegExp(r'^.*?Exception:\s*'), '');
        } else {
          message = 'Could not verify. Request a fresh code.';
        }
      } else {
        message = 'Could not verify. Request a fresh code.';
      }
      setState(() {
        _isLoading = false;
        _error = message;
      });
    }
  }

  String _messageForReason(String? reason) {
    switch (reason) {
      case 'admin_not_found':
        return 'This number is not registered for admin access.';
      case 'expired':
        return 'Code expired. Request a fresh code.';
      case 'already_used':
        return 'Code already used. Request a fresh code.';
      case 'attempts_exceeded':
        return 'Too many attempts. Request a new code.';
      case 'invalid_code':
      case 'not_found':
        return 'That code was not accepted.';
      default:
        return 'Could not verify admin access.';
    }
  }

  void _goBackToPhone() async {
    await _fadeController.reverse();
    if (!mounted) return;
    setState(() {
      _step = 'phone';
      for (final c in _otpControllers) {
        c.clear();
      }
      _error = null;
      _info = null;
    });
    _fadeController.forward();
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: _step == 'phone'
              ? _buildPhoneStep(context)
              : _buildOtpStep(context),
        ),
      ),
    );
  }

  // ─── Phone Step ───

  Widget _buildPhoneStep(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        // Back button
        _buildBackButton(
          context,
          onTap: () {
            context.go(_entryReturnPath(context));
          },
        ),

        const SizedBox(height: 48),

        // Title
        Center(
          child: Text(
            'ADMIN',
            style: tt.labelSmall?.copyWith(
              color: cs.primary,
              letterSpacing: 4,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Secure Access',
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 28,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Use the WhatsApp number assigned to your admin profile.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ),

        const SizedBox(height: 48),

        // "WHATSAPP NUMBER" label
        Text(
          'WHATSAPP NUMBER',
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),

        CountryPhoneInput.fromConfig(
          config: CountryRuntime.config,
          controller: _phoneController,
          onSubmitted: _canSendOtp ? _sendOtp : null,
          onChanged: (_) => setState(() {}),
        ),

        // Error / Info
        if (_error != null) ...[
          const SizedBox(height: 16),
          OtpInlineNotice(
            icon: LucideIcons.alertCircle,
            message: _error!,
            color: cs.error,
          ),
        ],
        if (_info != null) ...[
          const SizedBox(height: 16),
          OtpInlineNotice(
            icon: LucideIcons.messageSquare,
            message: _info!,
            color: cs.secondary,
          ),
        ],

        const SizedBox(height: 32),

        // "Get OTP" button
        OtpActionButton.gold(
          label: _isLoading
              ? 'Sending...'
              : _isCoolingDown
              ? 'Wait ${_cooldownSeconds}s'
              : 'Get OTP',
          icon: _isLoading ? null : const WhatsAppIcon(),
          isLoading: _isLoading,
          onPressed: _canSendOtp ? _sendOtp : null,
        ),
      ],
    );
  }

  // ─── OTP Step ───

  Widget _buildOtpStep(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        // Back button
        _buildBackButton(context, onTap: _goBackToPhone),

        const SizedBox(height: 48),

        // Title
        Center(
          child: Text(
            'VERIFY',
            style: tt.labelSmall?.copyWith(
              color: cs.secondary,
              letterSpacing: 4,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Enter Code',
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 28,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'A 6-digit code was sent to your WhatsApp.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
        if (_info != null) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              _info!,
              style: tt.bodySmall?.copyWith(color: cs.secondary),
            ),
          ),
        ],

        const SizedBox(height: 48),

        // OTP pill inputs
        OtpPillFields(
          controllers: _otpControllers,
          focusNodes: _otpFocusNodes,
          onComplete: _isLoading ? null : _verifyOtp,
        ),

        // Error
        if (_error != null) ...[
          const SizedBox(height: 20),
          OtpInlineNotice(
            icon: LucideIcons.alertCircle,
            message: _error!,
            color: cs.error,
          ),
        ],

        const SizedBox(height: 32),

        // Submit button
        OtpActionButton.green(
          label: _isLoading ? 'Verifying...' : 'Submit',
          icon: _isLoading
              ? null
              : Icon(
                  LucideIcons.checkCircle,
                  size: 22,
                  color: AppColors.onSecondary,
                ),
          isLoading: _isLoading,
          onPressed: _isLoading || _otpCode.length != 6 ? null : _verifyOtp,
        ),

        const SizedBox(height: 20),

        // Resend
        Center(
          child: GestureDetector(
            onTap: (_isLoading || _isCoolingDown) ? null : _sendOtp,
            child: Text(
              _isCoolingDown
                  ? 'Resend Code in ${_cooldownSeconds}s'
                  : 'Resend Code',
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: _isCoolingDown
                    ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                    : cs.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Shared Back Button ───

  Widget _buildBackButton(BuildContext context, {required VoidCallback onTap}) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppColors.white5),
          ),
          child: const Icon(LucideIcons.chevronLeft, size: 24),
        ),
      ),
    );
  }
}
