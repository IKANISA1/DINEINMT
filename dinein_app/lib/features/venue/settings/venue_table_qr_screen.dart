import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';
import 'venue_table_qr_pdf.dart';

const _qrExportBoundaryKey = Key('venue-table-qr-export-boundary');

class VenueTableQrScreen extends ConsumerStatefulWidget {
  const VenueTableQrScreen({super.key});

  @override
  ConsumerState<VenueTableQrScreen> createState() => _VenueTableQrScreenState();
}

class _VenueTableQrScreenState extends ConsumerState<VenueTableQrScreen> {
  final _tableNumberCtrl = TextEditingController(text: '4');
  final _cardKey = GlobalKey();
  int _tableNumber = 4;
  bool _sharing = false;

  @override
  void dispose() {
    _tableNumberCtrl.dispose();
    super.dispose();
  }

  void _setTableNumber(int value) {
    final sanitized = value < 1 ? 1 : value;
    setState(() {
      _tableNumber = sanitized;
      _tableNumberCtrl.text = sanitized.toString();
      _tableNumberCtrl.selection = TextSelection.collapsed(
        offset: _tableNumberCtrl.text.length,
      );
    });
  }

  Future<void> _shareQrCard(Venue venue) async {
    if (_sharing) return;

    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Could not capture QR card image.');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Could not capture QR card image.');
      }

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/table_qr_${venue.slug}_${_tableNumber.toString().padLeft(2, '0')}.png',
      );
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: '${venue.name} Table $_tableNumber QR',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export the QR card.')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final venueAsync = ref.watch(currentVenueProvider);

    return venueAsync.when(
      loading: () => const Center(
        child: SkeletonLoader(width: double.infinity, height: 240),
      ),
      error: (_, _) => ErrorState(
        message: 'Could not load venue.',
        onRetry: () => ref.invalidate(currentVenueProvider),
      ),
      data: (venue) {
        if (venue == null) {
          return const EmptyState(
            icon: LucideIcons.qrCode,
            title: 'No venue',
            subtitle: 'Claim a venue first.',
          );
        }

        final entry = buildVenueTableQrEntries(
          venue: venue,
          tableCount: _tableNumber,
        ).last;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space6,
            AppTheme.space6,
            AppTheme.space6,
            120,
          ),
          children: [
            Row(
              children: [
                PressableScale(
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      context.pop();
                    } else {
                      context.goNamed(AppRouteNames.venueSettings);
                    }
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Icon(
                      LucideIcons.chevronLeft,
                      size: 22,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Table QR Code',
                      style: tt.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'VENUE MANAGEMENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 32, 18, 18),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                boxShadow: AppTheme.clayShadow,
              ),
              child: Column(
                children: [
                  RepaintBoundary(
                    key: _cardKey,
                    child: KeyedSubtree(
                      key: _qrExportBoundaryKey,
                      child: _QrPosterCard(
                        entry: entry,
                        tableNumber: _tableNumber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        'TABLE NUMBER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.3,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.70),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainer,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: TextField(
                            controller: _tableNumberCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              if (parsed != null && parsed > 0) {
                                setState(() => _tableNumber = parsed);
                              }
                            },
                            onEditingComplete: () {
                              final parsed =
                                  int.tryParse(_tableNumberCtrl.text.trim()) ??
                                  1;
                              _setTableNumber(parsed);
                              FocusScope.of(context).unfocus();
                            },
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              fillColor: Colors.transparent,
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 18,
                              ),
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(
                                  right: 8,
                                  top: 8,
                                  bottom: 8,
                                ),
                                child: Container(
                                  width: 30,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      InkWell(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(10),
                                            ),
                                        onTap: () =>
                                            _setTableNumber(_tableNumber + 1),
                                        child: const SizedBox(
                                          width: 30,
                                          height: 14,
                                          child: Center(
                                            child: Icon(
                                              LucideIcons.chevronUp,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: 1,
                                        width: 30,
                                        color: Colors.white.withValues(
                                          alpha: 0.06,
                                        ),
                                      ),
                                      InkWell(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              bottom: Radius.circular(10),
                                            ),
                                        onTap: () =>
                                            _setTableNumber(_tableNumber - 1),
                                        child: const SizedBox(
                                          width: 30,
                                          height: 14,
                                          child: Center(
                                            child: Icon(
                                              LucideIcons.chevronDown,
                                              size: 14,
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
                        ),
                      ),
                      const SizedBox(width: 10),
                      PressableScale(
                        onTap: _sharing ? null : () => _shareQrCard(venue),
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.14,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _sharing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onPrimary,
                                    ),
                                  )
                                : const Icon(
                                    LucideIcons.externalLink,
                                    size: 22,
                                    color: AppColors.onPrimary,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QrPosterCard extends StatelessWidget {
  final VenueTableQrEntry entry;
  final int tableNumber;

  const _QrPosterCard({required this.entry, required this.tableNumber});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Column(
        children: [
          Text(
            'TABLE $tableNumber',
            style: tt.headlineLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'SCAN TO GET DINEIN APP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
              color: cs.onSurfaceVariant.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF181A1C),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  QrImageView(
                    data: entry.redirectUri.toString(),
                    version: QrVersions.auto,
                    gapless: true,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.primary,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.primary,
                    ),
                    backgroundColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'IN',
                        style: tt.headlineSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
