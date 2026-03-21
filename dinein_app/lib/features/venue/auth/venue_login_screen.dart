import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/whatsapp_otp_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

class VenueLoginScreen extends StatefulWidget {
  const VenueLoginScreen({super.key});

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
  String get _fullPhone => '+356${_phoneController.text.trim()}';
  String get _otpCode => _otpControllers.map((c) => c.text).join();

  // ─── Send OTP ───

  Future<void> _sendOtp() async {
    if (_isCoolingDown) return;
    final local = _phoneController.text.trim();
    if (local.length < 7) {
      setState(() => _error = 'Enter your 8-digit Maltese phone number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });

    try {
      final challenge = await WhatsAppOtpService.instance.sendOtp(_fullPhone);
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not send code. Check the number and retry.';
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

    final result = await WhatsAppOtpService.instance.verifyOtpDetailed(
      phone: _fullPhone,
      verificationId: challenge.verificationId,
      code: code,
    );

    if (!result.verified) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'That code was not accepted. Request a fresh code.';
      });
      return;
    }

    final venueSession = result.venueSession;
    if (venueSession != null) {
      await AuthRepository.instance.saveVenueSession(venueSession);
      if (!mounted) return;
      context.goNamed(AppRouteNames.venueDashboard);
      return;
    }

    if (result.claimStatus == 'pending') {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error =
            'Your venue claim is still under review. Try again after approval.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = result.claimStatus == 'not_found'
          ? 'No approved venue found for this number. Claim your venue first.'
          : 'Verified, but no session was issued. Request a fresh code.';
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
        _buildBackButton(context, onTap: () {
          context.goNamed(AppRouteNames.splash);
        }),

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

        MaltaPhoneInput(
          controller: _phoneController,
          onSubmitted: _isLoading ? null : _sendOtp,
          onChanged: (_) => setState(() {}),
        ),

        if (_error != null) ...[
          const SizedBox(height: 16),
          _InlineNotice(
            icon: LucideIcons.alertCircle,
            message: _error!,
            color: cs.error,
          ),
        ],
        if (_info != null) ...[
          const SizedBox(height: 16),
          _InlineNotice(
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
          onPressed: (_isLoading || _isCoolingDown) ? null : _sendOtp,
        ),

        const SizedBox(height: 32),

        Center(
          child: GestureDetector(
            onTap: () => context.pushNamed(AppRouteNames.venueClaim),
            child: Text(
              'CLAIM YOUR VENUE',
              style: tt.labelSmall?.copyWith(
                color: cs.primary,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
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
          _InlineNotice(
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
              : Icon(LucideIcons.checkCircle, size: 22, color: AppColors.onSecondary),
          isLoading: _isLoading,
          onPressed: _isLoading || _otpCode.length != 6 ? null : _verifyOtp,
        ),

        const SizedBox(height: 20),

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

// ─── Inline Notice (error / info) ───

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _InlineNotice({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: tt.bodySmall?.copyWith(color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
