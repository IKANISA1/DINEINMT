import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:core_pkg/config/country_runtime.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/services/auth_repository.dart';
import 'package:dinein_app/core/services/pwa_install_service.dart';
import 'package:dinein_app/core/services/whatsapp_otp_service.dart';
import 'package:dinein_app/core/infrastructure/support_contact_service.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

class VenueLoginScreen extends StatefulWidget {
  final Future<WhatsAppOtpChallenge> Function(String phone, {String appScope})?
  sendOtpOverride;
  final Future<WhatsAppOtpVerificationResult> Function({
    required String phone,
    required String verificationId,
    required String code,
    String appScope,
  })?
  verifyOtpOverride;
  final Future<void> Function(VenueAccessSession session)?
  saveVenueSessionOverride;

  const VenueLoginScreen({
    super.key,
    this.sendOtpOverride,
    this.verifyOtpOverride,
    this.saveVenueSessionOverride,
  });

  @override
  State<VenueLoginScreen> createState() => _VenueLoginScreenState();
}

class _VenueLoginScreenState extends State<VenueLoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _error;
  String? _info;
  String _step = 'phone';
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
    if (error is WhatsAppOtpException) {
      return switch (error.reason) {
        'venue_not_found' => true,
        _ => error.message.toLowerCase().contains(
          'not linked to a validated venue',
        ),
      };
    }
    final raw = error.toString().toLowerCase();
    return raw.contains('not linked to a validated venue') ||
        raw.contains('not registered for venue');
  }

  Future<WhatsAppOtpChallenge> _sendOtpRequest(String phone) {
    return widget.sendOtpOverride?.call(phone, appScope: 'venue') ??
        WhatsAppOtpService.instance.sendOtp(phone, appScope: 'venue');
  }

  Future<WhatsAppOtpVerificationResult> _verifyOtpRequest({
    required String phone,
    required String verificationId,
    required String code,
  }) {
    return widget.verifyOtpOverride?.call(
          phone: phone,
          verificationId: verificationId,
          code: code,
          appScope: 'venue',
        ) ??
        WhatsAppOtpService.instance.verifyOtpDetailed(
          phone: phone,
          verificationId: verificationId,
          code: code,
        );
  }

  Future<void> _saveVenueSession(VenueAccessSession session) {
    return widget.saveVenueSessionOverride?.call(session) ??
        AuthRepository.instance.saveVenueSession(session);
  }

  String? _postLoginTarget(BuildContext context) {
    final raw = GoRouterState.of(
      context,
    ).uri.queryParameters[AppRouteParams.returnTo];
    if (raw == null || raw.trim().isEmpty) return null;

    final target = Uri.tryParse(raw);
    if (target == null || !target.path.startsWith('/venue')) return null;
    if (target.path == AppRoutePaths.venueLogin) return null;
    return target.toString();
  }

  String _verificationFailureMessage(String? reason) {
    return switch (reason) {
      'expired' => 'This code expired. Request a fresh code.',
      'attempts_exceeded' =>
        'Too many incorrect attempts. Request a fresh code.',
      'not_found' => 'This code was not recognized. Request a fresh code.',
      _ => 'That code was not accepted. Request a fresh code.',
    };
  }

  String _verificationExceptionMessage(WhatsAppOtpException error) {
    return switch (error.reason) {
      'network_error' =>
        'Could not verify the code right now. Check your connection and retry.',
      'delivery_failed' =>
        'WhatsApp delivery is currently unavailable. Request a fresh code shortly.',
      _ => error.message,
    };
  }

  Future<void> _showVenueSupportDialog({
    required String title,
    required String message,
  }) {
    return showAccessSupportDialog(
      context,
      title: title,
      message: message,
      ctaLabel: 'Contact Admin',
      showWhatsAppBadge: true,
      onContactSupport: () => SupportContactService.contactSupport(
        context,
        whatsAppNumber: CountryRuntime.config.venueAccessWhatsApp,
        email: CountryRuntime.config.venueAccessEmail,
      ),
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
      setState(
        () => _error =
            'Enter your $_expectedPhoneLength-digit ${CountryRuntime.config.country.label} phone number.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });

    try {
      final challenge = await _sendOtpRequest(_fullPhone);
      if (!mounted) return;
      _startCooldown();

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
        await _showVenueSupportDialog(
          title: 'Venue Access Not Found',
          message:
              'This WhatsApp number is not linked to a validated venue account. Contact support to activate or recover venue access.',
        );
        return;
      }
      final message = switch (error) {
        WhatsAppOtpException(reason: 'network_error') =>
          'Could not send code right now. Check your connection and retry.',
        WhatsAppOtpException(reason: 'delivery_failed') =>
          'WhatsApp delivery failed. Retry in a moment.',
        WhatsAppOtpException(reason: 'rate_limited') =>
          'Too many requests. Wait a few minutes.',
        _ => 'Could not send code. Check the number and retry.',
      };
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
      setState(() => _error = 'Enter the full 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    late final WhatsAppOtpVerificationResult result;
    try {
      result = await _verifyOtpRequest(
        phone: _fullPhone,
        verificationId: challenge.verificationId,
        code: code,
      );
    } catch (error) {
      if (!mounted) return;
      if (_requiresSupportContact(error)) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
        await _showVenueSupportDialog(
          title: 'Venue Access Not Found',
          message:
              'This WhatsApp number is not linked to a validated venue account. Contact support to activate or recover venue access.',
        );
        return;
      }
      final message = error is WhatsAppOtpException
          ? _verificationExceptionMessage(error)
          : 'Could not verify the code right now. Request a fresh code.';
      setState(() {
        _isLoading = false;
        _error = message;
      });
      return;
    }

    if (!result.verified) {
      if (!mounted) return;
      if (result.reason == 'venue_not_found') {
        setState(() {
          _isLoading = false;
          _error = null;
        });
        await _showVenueSupportDialog(
          title: 'Venue Access Not Found',
          message:
              'This WhatsApp number is no longer linked to a validated venue account. Contact support to restore venue access.',
        );
        return;
      }
      setState(() {
        _isLoading = false;
        _error = _verificationFailureMessage(result.reason);
      });
      return;
    }

    final venueSession = result.venueSession;
    if (venueSession != null) {
      await _saveVenueSession(venueSession);
      PwaInstallService.triggerIfEligible(reason: 'venue_login');
      if (!mounted) return;
      context.go(_postLoginTarget(context) ?? AppRoutePaths.venueDashboard);
      return;
    }

    setState(() {
      _isLoading = false;
      _error = 'Verified, but no session was issued. Request a fresh code.';
    });
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FadeTransition(
              opacity: _fadeController,
              child: _step == 'phone'
                  ? _buildPhoneStep(context)
                  : _buildOtpStep(context),
            ),
          ),
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
        _buildBackButton(
          context,
          onTap: () {
            context.go(_entryReturnPath(context));
          },
        ),

        const SizedBox(height: 48),

        Center(
          child: Text(
            'VENUE',
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
            'Portal',
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 28,
              color: cs.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Access your venue workspace with WhatsApp OTP.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ),

        const SizedBox(height: 48),

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

        const SizedBox(height: 32),
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
        _buildBackButton(context, onTap: _goBackToPhone),

        const SizedBox(height: 48),

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

        OtpPillFields(
          controllers: _otpControllers,
          focusNodes: _otpFocusNodes,
          onComplete: _isLoading ? null : _verifyOtp,
        ),

        if (_error != null) ...[
          const SizedBox(height: 20),
          OtpInlineNotice(
            icon: LucideIcons.alertCircle,
            message: _error!,
            color: cs.error,
          ),
        ],

        const SizedBox(height: 32),

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

        Center(
          child: PressableScale(
            semanticLabel: 'Resend WhatsApp code',
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
        semanticLabel: 'Go back',
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
