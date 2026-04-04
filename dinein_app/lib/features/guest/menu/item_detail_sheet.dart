import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:db_pkg/models/models.dart';
import 'package:ui/widgets/shared_widgets.dart';
import 'menu_item_badges.dart';

/// Item detail bottom sheet — shown when tapping a menu item.
/// Allows selecting quantity and viewing full description.
class ItemDetailSheet extends StatefulWidget {
  final MenuItem item;
  final int initialQuantity;
  final ValueChanged<int> onQuantityChanged;
  final String currencySymbol;

  const ItemDetailSheet({
    super.key,
    required this.item,
    this.initialQuantity = 0,
    required this.onQuantityChanged,
    this.currencySymbol = '€',
  });

  /// Show the bottom sheet for a menu item.
  static Future<void> show(
    BuildContext context, {
    required MenuItem item,
    int initialQuantity = 0,
    required ValueChanged<int> onQuantityChanged,
    String currencySymbol = '€',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemDetailSheet(
        item: item,
        initialQuantity: initialQuantity,
        onQuantityChanged: onQuantityChanged,
        currencySymbol: currencySymbol,
      ),
    );
  }

  @override
  State<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<ItemDetailSheet> {
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final item = widget.item;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXxl),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Handle ───
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space6),

              // ─── Item Image ───
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                child: SizedBox(
                  width: double.infinity,
                  height: 200,
                  child: DineInImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: LucideIcons.chefHat,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: AppTheme.space6),

              if (item.guestDisplayTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space3),
                  child: MenuItemBadges(item: item),
                ),

              // ─── Name + Price ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(item.name, style: tt.headlineMedium)),
                  const SizedBox(width: AppTheme.space4),
                  Text(
                    '${widget.currencySymbol}${item.price.toStringAsFixed(2)}',
                    style: tt.headlineMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.space3),

              Text(
                item.description,
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: AppTheme.space6),

              // ─── Allergen Info ───
              Container(
                padding: const EdgeInsets.all(AppTheme.space4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.shieldAlert, size: 18, color: cs.tertiary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please inform staff of any allergies before ordering.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.space6),

              // ─── Special Requests ───
              Text(
                'SPECIAL REQUESTS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.space2),
              TextField(
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Any special preferences or dietary needs...',
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.space8),

              // ─── Quantity Selector ───
              Container(
                padding: const EdgeInsets.all(AppTheme.space4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StepperButton(
                      icon: LucideIcons.minus,
                      onTap: _quantity > 0
                          ? () => setState(() => _quantity--)
                          : null,
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '$_quantity',
                        textAlign: TextAlign.center,
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _StepperButton(
                      icon: LucideIcons.plus,
                      isPrimary: true,
                      onTap: () => setState(() => _quantity++),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.space6),

              // ─── Add to Cart CTA ───
              SizedBox(
                width: double.infinity,
                child: PremiumButton(
                  label: _quantity > 0
                      ? 'ADD TO CART  •  ${widget.currencySymbol}${(item.price * _quantity).toStringAsFixed(2)}'
                      : 'SELECT QUANTITY',
                  onPressed: _quantity > 0
                      ? () {
                          widget.onQuantityChanged(_quantity);
                          Navigator.of(context).pop();
                        }
                      : null,
                  icon: _quantity > 0 ? LucideIcons.plus : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final bool isPrimary;
  final VoidCallback? onTap;

  const _StepperButton({
    required this.icon,
    this.isPrimary = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDisabled = onTap == null;

    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isPrimary
              ? cs.primary
              : isDisabled
              ? cs.surfaceContainerHigh.withValues(alpha: 0.50)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isPrimary
              ? cs.onPrimary
              : isDisabled
              ? cs.onSurfaceVariant.withValues(alpha: 0.20)
              : cs.onSurface,
        ),
      ),
    );
  }
}
