import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:core_pkg/config/country_config_provider.dart';
import 'package:core_pkg/constants/app_download_links.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/shared/widgets/branded_qr_tools.dart';
import 'package:ui/theme/app_layout.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';
import 'venue_table_qr_pdf.dart';

const _qrExportBoundaryKey = Key('venue-table-qr-export-boundary');

class VenueTableQrScreen extends ConsumerStatefulWidget {
  const VenueTableQrScreen({super.key});

  @override
  ConsumerState<VenueTableQrScreen> createState() => _VenueTableQrScreenState();
}

class _VenueTableQrScreenState extends ConsumerState<VenueTableQrScreen> {
  final _tableNumberCtrl = TextEditingController(text: '4');
  final _guestQrKey = GlobalKey();
  final _venueAppQrKey = GlobalKey();
  final _tableQrKey = GlobalKey();
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

  Future<void> _sharePoster(
    GlobalKey boundaryKey, {
    required String fileName,
    required String subject,
  }) async {
    if (_sharing) return;

    setState(() => _sharing = true);
    try {
      await shareQrPoster(
        context,
        boundaryKey: boundaryKey,
        fileName: fileName,
        subject: subject,
      );
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
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
            subtitle: 'No venue linked to this account.',
          );
        }

        final config = ref.read(countryConfigProvider);
        final guestUri = buildVenueDeepLinkUri(
          slug: venue.slug,
          config: config,
        );
        final appUri = buildVenueDownloadRedirectUri(
          slug: venue.slug,
          config: config,
          venueName: venue.name,
        );
        final tableEntry = buildVenueTableQrEntries(
          venue: venue,
          tableCount: _tableNumber,
          config: config,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Venue QR Codes',
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
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space5),
            Text(
              'Generate clean QR posters for direct guest ordering, the venue app redirect, and table-specific ordering flows.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.space6),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= AppLayout.guestTabletBreakpoint;
                final guestCard = Expanded(
                  child: _QrManagementCard(
                    boundaryKey: _guestQrKey,
                    title: 'Guest Menu QR',
                    subtitle:
                        'Guests scan this QR to open the venue menu directly.',
                    uri: guestUri,
                    isBusy: _sharing,
                    onShare: () => _sharePoster(
                      _guestQrKey,
                      fileName: '${venue.slug}_guest_menu_qr.png',
                      subject: '${venue.name} guest menu QR',
                    ),
                    onCopy: () => copyQrLink(
                      context,
                      uri: guestUri,
                      feedbackMessage: 'Guest menu URL copied.',
                    ),
                    onOpen: () => openQrLink(
                      context,
                      uri: guestUri,
                      label: 'guest menu URL',
                    ),
                  ),
                );
                final venueCard = Expanded(
                  child: _QrManagementCard(
                    boundaryKey: _venueAppQrKey,
                    title: 'Venue App QR',
                    subtitle:
                        'Guests scan this QR to open the smart venue app link.',
                    uri: appUri,
                    isBusy: _sharing,
                    onShare: () => _sharePoster(
                      _venueAppQrKey,
                      fileName: '${venue.slug}_venue_app_qr.png',
                      subject: '${venue.name} venue app QR',
                    ),
                    onCopy: () => copyQrLink(
                      context,
                      uri: appUri,
                      feedbackMessage: 'Venue app URL copied.',
                    ),
                    onOpen: () => openQrLink(
                      context,
                      uri: appUri,
                      label: 'venue app URL',
                    ),
                  ),
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      guestCard,
                      const SizedBox(width: AppTheme.space4),
                      venueCard,
                    ],
                  );
                }

                return Column(
                  children: [
                    guestCard,
                    const SizedBox(height: AppTheme.space4),
                    venueCard,
                  ],
                );
              },
            ),
            const SizedBox(height: AppTheme.space6),
            ClayCard(
              padding: const EdgeInsets.all(AppTheme.space5),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide =
                      constraints.maxWidth >= AppLayout.guestTabletBreakpoint;

                  final poster = RepaintBoundary(
                    key: _tableQrKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TABLE $_tableNumber',
                          style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: AppTheme.space4),
                        KeyedSubtree(
                          key: _qrExportBoundaryKey,
                          child: BrandedQrPoster(
                            uri: tableEntry.redirectUri,
                            title: 'SCAN TO ORDER TABLE $_tableNumber',
                          ),
                        ),
                      ],
                    ),
                  );

                  final controls = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Table QR',
                        style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space2),
                      Text(
                        'Create a table-specific QR poster that links guests straight into ordering for that table.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space5),
                      Text(
                        'TABLE NUMBER',
                        style: tt.labelSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space2),
                      _TableNumberEditor(
                        controller: _tableNumberCtrl,
                        onDecrement: () => _setTableNumber(_tableNumber - 1),
                        onIncrement: () => _setTableNumber(_tableNumber + 1),
                        onChanged: (value) {
                          final parsed = int.tryParse(value);
                          if (parsed != null && parsed > 0) {
                            setState(() => _tableNumber = parsed);
                          }
                        },
                        onEditingComplete: () {
                          final parsed =
                              int.tryParse(_tableNumberCtrl.text.trim()) ?? 1;
                          _setTableNumber(parsed);
                          FocusScope.of(context).unfocus();
                        },
                      ),
                      const SizedBox(height: AppTheme.space5),
                      SizedBox(
                        width: double.infinity,
                        child: PremiumButton(
                          label: 'SHARE TABLE QR',
                          icon: LucideIcons.share2,
                          isLoading: _sharing,
                          onPressed: _sharing
                              ? null
                              : () => _sharePoster(
                                  _tableQrKey,
                                  fileName:
                                      '${venue.slug}_table_${_tableNumber.toString().padLeft(2, '0')}_qr.png',
                                  subject:
                                      '${venue.name} table $_tableNumber QR',
                                ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space3),
                      SizedBox(
                        width: double.infinity,
                        child: PremiumButton(
                          label: 'COPY TABLE URL',
                          icon: LucideIcons.copy,
                          isOutlined: true,
                          onPressed: () => copyQrLink(
                            context,
                            uri: tableEntry.redirectUri,
                            feedbackMessage: 'Table URL copied.',
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space3),
                      SizedBox(
                        width: double.infinity,
                        child: PremiumButton(
                          label: 'OPEN TABLE URL',
                          icon: LucideIcons.externalLink,
                          isOutlined: true,
                          onPressed: () => openQrLink(
                            context,
                            uri: tableEntry.redirectUri,
                            label: 'table URL',
                          ),
                        ),
                      ),
                    ],
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: poster),
                        const SizedBox(width: AppTheme.space5),
                        Expanded(flex: 4, child: controls),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      poster,
                      const SizedBox(height: AppTheme.space5),
                      controls,
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QrManagementCard extends StatelessWidget {
  final GlobalKey boundaryKey;
  final String title;
  final String subtitle;
  final Uri uri;
  final bool isBusy;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onOpen;

  const _QrManagementCard({
    required this.boundaryKey,
    required this.title,
    required this.subtitle,
    required this.uri,
    required this.isBusy,
    required this.onShare,
    required this.onCopy,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ClayCard(
      padding: const EdgeInsets.all(AppTheme.space5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackContent = constraints.maxWidth < 520;
          final poster = RepaintBoundary(
            key: boundaryKey,
            child: BrandedQrPoster(uri: uri),
          );

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: AppTheme.space2),
              Text(
                subtitle,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.space4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.space3),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Text(
                  uri.toString(),
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              SizedBox(
                width: double.infinity,
                child: PremiumButton(
                  label: 'SHARE QR',
                  icon: LucideIcons.share2,
                  isLoading: isBusy,
                  onPressed: isBusy ? null : onShare,
                ),
              ),
              const SizedBox(height: AppTheme.space3),
              SizedBox(
                width: double.infinity,
                child: PremiumButton(
                  label: 'COPY URL',
                  icon: LucideIcons.copy,
                  isOutlined: true,
                  onPressed: onCopy,
                ),
              ),
              const SizedBox(height: AppTheme.space3),
              SizedBox(
                width: double.infinity,
                child: PremiumButton(
                  label: 'OPEN URL',
                  icon: LucideIcons.externalLink,
                  isOutlined: true,
                  onPressed: onOpen,
                ),
              ),
            ],
          );

          if (stackContent) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                poster,
                const SizedBox(height: AppTheme.space5),
                content,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: poster),
              const SizedBox(width: AppTheme.space5),
              Expanded(flex: 4, child: content),
            ],
          );
        },
      ),
    );
  }
}

class _TableNumberEditor extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final ValueChanged<String> onChanged;
  final VoidCallback onEditingComplete;

  const _TableNumberEditor({
    required this.controller,
    required this.onDecrement,
    required this.onIncrement,
    required this.onChanged,
    required this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(LucideIcons.minus),
          ),
          Expanded(
            child: TextField(
              key: const Key('table-qr-number-field'),
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              onEditingComplete: onEditingComplete,
              textAlign: TextAlign.center,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppTheme.space2,
                  vertical: AppTheme.space3,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(LucideIcons.plus),
          ),
        ],
      ),
    );
  }
}
