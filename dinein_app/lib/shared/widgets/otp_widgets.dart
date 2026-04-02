import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/config/country_config.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'pressable_scale.dart';

/// Normalize phone input — strips country code prefix, limits to [maxDigits].
String normalizePhoneLocalInput(
  String value, {
  String countryCode = '356',
  int maxDigits = 8,
}) {
  var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00$countryCode')) {
    digits = digits.substring(2 + countryCode.length);
  } else if (digits.startsWith(countryCode) && digits.length > maxDigits) {
    digits = digits.substring(countryCode.length);
  }
  if (digits.length > maxDigits) {
    digits = digits.substring(0, maxDigits);
  }
  return digits;
}

/// Legacy alias for Malta.
String normalizeMaltesePhoneLocalInput(String value) =>
    normalizePhoneLocalInput(value, countryCode: '356', maxDigits: 8);

bool isValidPhoneLocalInput(
  String value, {
  String countryCode = '356',
  int expectedLength = 8,
}) {
  final n = normalizePhoneLocalInput(
    value,
    countryCode: countryCode,
    maxDigits: expectedLength,
  );
  return n.length == expectedLength && !n.startsWith(countryCode);
}

/// Legacy alias for Malta.
bool isValidMaltesePhoneLocalInput(String value) =>
    isValidPhoneLocalInput(value, countryCode: '356', expectedLength: 8);

class PhoneTextInputFormatter extends TextInputFormatter {
  final String countryCode;
  final int maxDigits;
  const PhoneTextInputFormatter({this.countryCode = '356', this.maxDigits = 8});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalizePhoneLocalInput(
      newValue.text,
      countryCode: countryCode,
      maxDigits: maxDigits,
    );
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
      composing: TextRange.empty,
    );
  }
}

/// Legacy alias.
typedef MaltesePhoneTextInputFormatter = PhoneTextInputFormatter;

// ─────────────────────────────────────────────────────────────
// CountryPhoneInput — configurable country code pill + phone field
// ─────────────────────────────────────────────────────────────

/// Split country-code + phone number input matching the DineIn design system.
///
/// Renders a non-editable country pill on the left and a dark rounded
/// phone number field on the right. The [controller] value contains only
/// the local part (no country code).
class CountryPhoneInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;
  final String countryFlag;
  final String dialCode;
  final String hintText;
  final String countryCode;
  final int maxDigits;

  const CountryPhoneInput({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.onChanged,
    this.countryFlag = '🇲🇹',
    this.dialCode = '+356',
    this.hintText = '9912 3456',
    this.countryCode = '356',
    this.maxDigits = 8,
  });

  /// Create from a [CountryConfig].
  factory CountryPhoneInput.fromConfig({
    Key? key,
    required CountryConfig config,
    required TextEditingController controller,
    VoidCallback? onSubmitted,
    ValueChanged<String>? onChanged,
  }) {
    final isRw = config.country == Country.rw;
    return CountryPhoneInput(
      key: key,
      controller: controller,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      countryFlag: config.countryFlag,
      dialCode: config.countryDialCode,
      hintText: isRw ? '078 123 4567' : '9912 3456',
      countryCode: config.defaultCountryCode,
      maxDigits: isRw ? 10 : 8,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Country code pill
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.white5),
            boxShadow: AppTheme.ambientShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(countryFlag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                dialCode,
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

        // Phone number field
        Expanded(
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: controller.text.isNotEmpty
                    ? cs.primary.withValues(alpha: 0.5)
                    : AppColors.white5,
                width: controller.text.isNotEmpty ? 1.5 : 1,
              ),
              boxShadow: AppTheme.ambientShadow,
            ),
            child: Center(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSubmitted?.call(),
                onChanged: onChanged,
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                  letterSpacing: 1,
                ),
                inputFormatters: [
                  PhoneTextInputFormatter(
                    countryCode: countryCode,
                    maxDigits: maxDigits,
                  ),
                ],
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 22,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  filled: false,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Legacy alias for backward compatibility.
typedef MaltaPhoneInput = CountryPhoneInput;

// ─────────────────────────────────────────────────────────────
// OtpPillFields — 6 individual pill-shaped digit inputs
// ─────────────────────────────────────────────────────────────

/// Six individual pill-shaped OTP digit inputs with auto-advance,
/// backspace navigation, and optional auto-submit.
class OtpPillFields extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;

  /// Called when the complete 6-digit code is entered.
  final VoidCallback? onComplete;

  const OtpPillFields({
    super.key,
    required this.controllers,
    required this.focusNodes,
    this.onComplete,
  });

  String get code => controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      focusNodes[index + 1].requestFocus();
    }
    if (code.length == 6) {
      onComplete?.call();
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        controllers[index].text.isEmpty &&
        index > 0) {
      controllers[index - 1].clear();
      focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final hasValue = controllers[index].text.isNotEmpty;
        final isFocused = focusNodes[index].hasFocus;

        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 10),
          child: Focus(
            onKeyEvent: (_, event) {
              _onKeyEvent(index, event);
              return KeyEventResult.ignored;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: hasValue
                    ? AppColors.surfaceContainerHigh
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(27),
                border: Border.all(
                  color: isFocused
                      ? cs.primary.withValues(alpha: 0.75)
                      : hasValue
                      ? cs.onSurfaceVariant.withValues(alpha: 0.18)
                      : cs.onSurfaceVariant.withValues(alpha: 0.10),
                  width: isFocused ? 1.6 : 1,
                ),
              ),
              child: Center(
                child: TextField(
                  controller: controllers[index],
                  focusNode: focusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  onChanged: (v) => _onDigitChanged(index, v),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// OtpActionButton — Large action button (gold / green)
// ─────────────────────────────────────────────────────────────

/// Full-width 64px pill button with colored background, label, and optional
/// trailing icon. Includes a color-matched glow shadow when enabled.
class OtpActionButton extends StatelessWidget {
  final String label;
  final Widget? icon;
  final bool isLoading;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;

  const OtpActionButton({
    super.key,
    required this.label,
    this.icon,
    this.isLoading = false,
    required this.color,
    required this.textColor,
    this.onPressed,
  });

  /// Gold "Get OTP" / "Send" style.
  const OtpActionButton.gold({
    super.key,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.onPressed,
  }) : color = AppColors.primary,
       textColor = AppColors.onPrimary;

  /// Green "Submit" / "Verify" style.
  const OtpActionButton.green({
    super.key,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.onPressed,
  }) : color = AppColors.secondary,
       textColor = AppColors.onSecondary;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDisabled = onPressed == null;

    return PressableScale(
      onTap: isDisabled ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 72,
        decoration: BoxDecoration(
          color: isDisabled ? color.withValues(alpha: 0.35) : color,
          borderRadius: BorderRadius.circular(20),
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
                    if (icon != null) ...[const SizedBox(width: 12), icon!],
                  ],
                ),
        ),
      ),
    );
  }
}

class OtpInlineNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const OtpInlineNotice({
    super.key,
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

// ─────────────────────────────────────────────────────────────
// WhatsAppIcon — Compact branded icon for OTP buttons
// ─────────────────────────────────────────────────────────────

/// Small WhatsApp-style icon rendered via CustomPaint.
class WhatsAppIcon extends StatelessWidget {
  final Color color;
  const WhatsAppIcon({super.key, this.color = AppColors.onPrimary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _WhatsAppPainter(color: color)),
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

    canvas.drawCircle(Offset(cx, cy), r, paint);

    final phonePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
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
