import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:db_pkg/models/models.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

class ShareVenueDialog extends StatefulWidget {
  final Venue venue;
  final Uri shareUri;

  const ShareVenueDialog({super.key, required this.venue, required this.shareUri});

  @override
  State<ShareVenueDialog> createState() => ShareVenueDialogState();
}


class ShareVenueDialogState extends State<ShareVenueDialog> {
  bool _copied = false;

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.shareUri.toString()));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  Future<void> _shareLink() async {
    await SharePlus.instance.share(
      ShareParams(
        title: '${widget.venue.name} on DINEIN',
        text:
            'Check out ${widget.venue.name} on DINEIN.\n'
            '${widget.shareUri}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radius3xl),
          border: Border.all(color: AppColors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(LucideIcons.qrCode, size: 20, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SHARE VENUE',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Digital experience',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                PressableScale(
                  onTap: () => Navigator.of(context).pop(),
                  semanticLabel: 'Close dialog',
                  minTouchTargetSize: const Size(44, 44),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.white5,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(
                      LucideIcons.x,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            Container(
              padding: const EdgeInsets.all(AppTheme.space8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
              ),
              child: QrImageView(
                data: widget.shareUri.toString(),
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF121416),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF121416),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            Text(
              widget.venue.name,
              textAlign: TextAlign.center,
              style: tt.headlineSmall?.copyWith(letterSpacing: -0.8),
            ),
            const SizedBox(height: 4),
            Text(
              'SCAN TO OPEN ON DINEIN',
              style: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.6,
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            SizedBox(
              width: double.infinity,
              child: PressableScale(
                onTap: _copyLink,
                semanticLabel: 'Copy link',
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: _copied ? cs.primary : AppColors.white5,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: _copied ? cs.primary : AppColors.white5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _copied ? LucideIcons.check : LucideIcons.copy,
                        size: 16,
                        color: _copied ? cs.onPrimary : cs.onSurface,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _copied ? 'COPIED!' : 'COPY LINK',
                        style: TextStyle(
                          color: _copied ? cs.onPrimary : cs.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space3),
            TextButton(
              onPressed: _shareLink,
              child: Text(
                'SHARE LINK',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

