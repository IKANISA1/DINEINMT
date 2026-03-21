import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

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

  String get _fullPhone => '+356${_phoneController.text.trim()}';

  String get _otpCode =>
      _otpControllers.map((c) => c.text).join();

  // ─── Send OTP ───

  Future<void> _sendOtp() async {
    if (_isCoolingDown) return;
    final local = _phoneController.text.trim();
    if (local.length < 7) {
      setState(() {
        _error = 'Enter your 8-digit Maltese phone number.';
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
      String message;
      if (error is Exception) {
        final raw = error.toString();
        if (raw.contains('not registered for admin')) {
          message = 'This number is not registered for admin access.';
        } else if (raw.contains('Too many')) {
          message = 'Too many requests. Wait a few minutes.';
        } else {
          message = 'Could not send code. Check the number and retry.';
        }
      } else {
        message = 'Could not send code. Check the number and retry.';
      }
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
        _buildBackButton(context, onTap: () {
          context.goNamed(AppRouteNames.splash);
        }),

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

        // Country code + phone number row
        Row(
          children: [
            // Country code pill
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🇲🇹', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text(
                    '+356',
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    LucideIcons.chevronDown,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Phone number input
            Expanded(
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _phoneController.text.isNotEmpty
                        ? cs.primary.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _isLoading ? null : _sendOtp(),
                    onChanged: (_) => setState(() {}),
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      letterSpacing: 1,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: InputDecoration(
                      hintText: '9912 3456',
                      hintStyle: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 22,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      filled: false,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Error / Info
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: tt.bodyMedium?.copyWith(color: cs.error),
            textAlign: TextAlign.center,
          ),
        ],
        if (_info != null) ...[
          const SizedBox(height: 16),
          Text(
            _info!,
            style: tt.bodyMedium?.copyWith(color: cs.secondary),
            textAlign: TextAlign.center,
          ),
        ],

        const SizedBox(height: 32),

        // "Get OTP" button
        _OtpActionButton(
          label: _isLoading
              ? 'Sending...'
              : _isCoolingDown
                  ? 'Wait ${_cooldownSeconds}s'
                  : 'Get OTP',
          icon: _isLoading
              ? null
              : const _WhatsAppIcon(),
          isLoading: _isLoading,
          color: AppColors.primary,
          textColor: AppColors.onPrimary,
          onPressed:
              (_isLoading || _isCoolingDown) ? null : _sendOtp,
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
          Text(
            _error!,
            style: tt.bodyMedium?.copyWith(color: cs.error),
            textAlign: TextAlign.center,
          ),
        ],

        const SizedBox(height: 32),

        // Submit button
        _OtpActionButton(
          label: _isLoading ? 'Verifying...' : 'Submit',
          icon: _isLoading
              ? null
              : Icon(
                  LucideIcons.checkCircle,
                  size: 22,
                  color: AppColors.onSecondary,
                ),
          isLoading: _isLoading,
          color: AppColors.secondary,
          textColor: AppColors.onSecondary,
          onPressed:
              _isLoading || _otpCode.length != 6 ? null : _verifyOtp,
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

// ─── Large Action Button (Gold / Green) ───

class _OtpActionButton extends StatelessWidget {
  final String label;
  final Widget? icon;
  final bool isLoading;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;

  const _OtpActionButton({
    required this.label,
    this.icon,
    this.isLoading = false,
    required this.color,
    required this.textColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDisabled = onPressed == null;

    return PressableScale(
      onTap: isDisabled ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: isDisabled
              ? color.withValues(alpha: 0.35)
              : color,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: textColor,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 12),
                      icon!,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── WhatsApp Icon (matching the design reference) ───

class _WhatsAppIcon extends StatelessWidget {
  const _WhatsAppIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _WhatsAppPainter(color: AppColors.onPrimary)),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  final Color color;
  _WhatsAppPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;

    // Circle
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // Phone icon inside (simplified)
    final phonePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    // Simplified phone handset shape
    path.moveTo(cx - 3, cy + 4);
    path.quadraticBezierTo(cx - 5, cy + 2, cx - 5, cy - 1);
    path.quadraticBezierTo(cx - 5, cy - 3, cx - 3, cy - 4);
    path.lineTo(cx - 1, cy - 4);
    path.quadraticBezierTo(cx, cy - 3, cx, cy - 1);
    path.lineTo(cx, cy + 1);
    path.quadraticBezierTo(cx, cy + 3, cx + 1, cy + 4);
    path.lineTo(cx + 3, cy + 4);
    path.quadraticBezierTo(cx + 5, cy + 3, cx + 5, cy + 1);
    path.quadraticBezierTo(cx + 5, cy - 1, cx + 3, cy - 2);

    canvas.drawPath(path, phonePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
