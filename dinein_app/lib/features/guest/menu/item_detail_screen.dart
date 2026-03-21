import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Full-page item detail screen — exact match of React ItemDetail.tsx.
///
/// 40vh hero image with gradient overlay, floating back/share/heart controls,
/// item info card with allergen info, special requests textarea,
/// quantity selector, fixed bottom "Add to Order" CTA.
class ItemDetailScreen extends ConsumerStatefulWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  int _quantity = 1;
  final _noteController = TextEditingController();
  bool _isSaved = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _handleAddToCart(MenuItem item) {
    final cartNotifier = ref.read(cartProvider.notifier);
    for (int i = 0; i < _quantity; i++) {
      cartNotifier.addItem(item);
    }
    context.pop();
  }

  Future<void> _shareItem(MenuItem item) async {
    await SharePlus.instance.share(
      ShareParams(
        title: '${item.name} on DineIn',
        text:
            'Check out ${item.name} on DineIn Malta.\n'
            '${item.description}\nPrice: ${ref.read(cartProvider).currencySymbol}${item.price.toStringAsFixed(2)}',
      ),
    );
  }

  void _toggleSavedItem(MenuItem item) {
    setState(() => _isSaved = !_isSaved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSaved
              ? '${item.name} saved for later.'
              : '${item.name} removed from saved items.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.of(context).size.height;

    // Resolve item from venues/providers — for now, use extra passed from route
    final extra = GoRouterState.of(context).extra;
    final MenuItem? item = extra is MenuItem ? extra : null;

    if (item == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.alertCircle,
                size: 48,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text('Item not found', style: tt.headlineSmall),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final currencySymbol = ref.watch(cartProvider).currencySymbol;
    final total = item.price * _quantity;

    return Scaffold(
      body: Stack(
        children: [
          // ─── Scrollable content ───
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ═══════════════════════════════════════
                //  HERO IMAGE (40vh)
                // ═══════════════════════════════════════
                SizedBox(
                  height: screenHeight * 0.40,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image
                      DineInImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        fallbackIcon: LucideIcons.chefHat,
                      ),
                      // Gradient overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                cs.surface.withValues(alpha: 0.10),
                                cs.surface,
                              ],
                              stops: const [0.0, 0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ═══════════════════════════════════════
                //  ITEM INFO CARD (overlapping hero -48px)
                // ═══════════════════════════════════════
                Transform.translate(
                  offset: const Offset(0, -48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space6,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.space8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tags
                          if (item.tags.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppTheme.space4,
                              ),
                              child: Wrap(
                                spacing: 8,
                                children: item.tags.map((tag) {
                                  final isSignature = tag == 'Signature';
                                  return StatusBadge(
                                    label: tag,
                                    color: isSignature
                                        ? cs.primary.withValues(alpha: 0.12)
                                        : cs.surfaceContainerHigh,
                                    textColor: isSignature
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  );
                                }).toList(),
                              ),
                            ),

                          // Name + Price
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: tt.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.space4),
                              Text(
                                '$currencySymbol${item.price.toStringAsFixed(2)}',
                                style: tt.headlineSmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Description
                          Text(
                            item.description,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.80,
                              ),
                              height: 1.5,
                            ),
                          ),


                          const SizedBox(height: AppTheme.space6),

                          // Allergen Info Card
                          Container(
                            padding: const EdgeInsets.all(AppTheme.space4),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    LucideIcons.info,
                                    size: 16,
                                    color: cs.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ALLERGENS',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2,
                                          color: cs.onSurfaceVariant.withValues(
                                            alpha: 0.60,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Please inform staff of any allergies',
                                        style: tt.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

                // ═══════════════════════════════════════
                //  SPECIAL REQUESTS
                // ═══════════════════════════════════════
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space6,
                  ),
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            'Special Requests',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.space4),
                        TextField(
                          controller: _noteController,
                          maxLines: 4,
                          style: tt.bodyMedium,
                          decoration: InputDecoration(
                            hintText: 'E.g. No onions, extra spicy, etc.',
                            hintStyle: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.40,
                              ),
                            ),
                            filled: true,
                            fillColor: cs.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: cs.primary.withValues(alpha: 0.50),
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(20),
                          ),
                        ),

                        const SizedBox(height: AppTheme.space8),

                        // ═══════════════════════════════════════
                        //  QUANTITY SELECTOR
                        // ═══════════════════════════════════════
                        Container(
                          padding: const EdgeInsets.all(AppTheme.space4),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  'Quantity',
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    // Minus
                                    GestureDetector(
                                      onTap: _quantity > 1
                                          ? () => setState(() => _quantity--)
                                          : null,
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: cs.surface,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          LucideIcons.minus,
                                          size: 20,
                                          color: _quantity > 1
                                              ? cs.onSurfaceVariant
                                              : cs.onSurfaceVariant.withValues(
                                                  alpha: 0.20,
                                                ),
                                        ),
                                      ),
                                    ),

                                    // Quantity display
                                    SizedBox(
                                      width: 48,
                                      child: Text(
                                        '$_quantity',
                                        textAlign: TextAlign.center,
                                        style: tt.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),

                                    // Plus
                                    GestureDetector(
                                      onTap: () => setState(() => _quantity++),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: cs.primary,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: cs.primary.withValues(
                                                alpha: 0.20,
                                              ),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          LucideIcons.plus,
                                          size: 20,
                                          color: cs.onPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom padding for fixed CTA
                const SizedBox(height: 120),
              ],
            ),
          ),

          // ═══════════════════════════════════════
          //  FLOATING CONTROLS (top of hero)
          // ═══════════════════════════════════════
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space6,
                  vertical: AppTheme.space4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back
                    _FloatingControl(
                      icon: LucideIcons.chevronLeft,
                      onTap: () => context.pop(),
                    ),
                    Row(
                      children: [
                        // Share
                        _FloatingControl(
                          icon: LucideIcons.share2,
                          onTap: () => _shareItem(item),
                        ),
                        const SizedBox(width: 12),
                        // Heart
                        _FloatingControl(
                          icon: _isSaved
                              ? LucideIcons.heart
                              : LucideIcons.heartOff,
                          iconColor: _isSaved ? AppColors.primary : null,
                          onTap: () => _toggleSavedItem(item),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ═══════════════════════════════════════
          //  FIXED BOTTOM CTA
          // ═══════════════════════════════════════
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space6,
                    AppTheme.space6,
                    AppTheme.space6,
                    32,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.80),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _handleAddToCart(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Add to Order',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '$currencySymbol${total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
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
          ),
        ],
      ),
    );
  }
}

// ─── Floating glass control button ───
class _FloatingControl extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _FloatingControl({
    required this.icon,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Icon(icon, size: 22, color: iconColor ?? Colors.white),
          ),
        ),
      ),
    );
  }
}
