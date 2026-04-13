import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

import 'menu_item_badges.dart';

/// Compact item detail bottom sheet for quick add flows.
class ItemDetailSheet extends StatefulWidget {
  final MenuItem item;
  final int initialQuantity;
  final ValueChanged<int> onQuantityChanged;
  final Country country;

  const ItemDetailSheet({
    super.key,
    required this.item,
    this.initialQuantity = 0,
    required this.onQuantityChanged,
    required this.country,
  });

  static Future<void> show(
    BuildContext context, {
    required MenuItem item,
    int initialQuantity = 0,
    required ValueChanged<int> onQuantityChanged,
    required Country country,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemDetailSheet(
        item: item,
        initialQuantity: initialQuantity,
        onQuantityChanged: onQuantityChanged,
        country: country,
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
    final item = widget.item;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXxl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space6,
            AppTheme.space3,
            AppTheme.space6,
            AppTheme.space6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                child: SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: DineInImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: LucideIcons.chefHat,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              if (item.guestDisplayTags.isNotEmpty) ...[
                MenuItemBadges(item: item),
                const SizedBox(height: AppTheme.space4),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(item.name, style: tt.headlineSmall)),
                  const SizedBox(width: AppTheme.space4),
                  Text(
                    widget.country.formatPrice(item.price),
                    style: tt.titleLarge?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space3),
              Text(
                item.description,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.84),
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              GuestSurfaceCard(
                padding: const EdgeInsets.all(AppTheme.space4),
                borderRadius: 22,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LucideIcons.shieldAlert,
                        size: 16,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space3),
                    Expanded(
                      child: Text(
                        'Tell staff about allergies before ordering.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.84),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              Row(
                children: [
                  _SheetStepper(
                    quantity: _quantity,
                    onDecrease: _quantity > 0
                        ? () => setState(() => _quantity--)
                        : null,
                    onIncrease: () => setState(() => _quantity++),
                  ),
                  const SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: FilledButton(
                      onPressed: _quantity > 0
                          ? () {
                              widget.onQuantityChanged(_quantity);
                              Navigator.of(context).pop();
                            }
                          : null,
                      child: Text(
                        _quantity > 0
                            ? 'Add ${widget.country.formatPrice(item.price * _quantity)}'
                            : 'Select quantity',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;

  const _SheetStepper({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          _SheetStepperButton(icon: LucideIcons.minus, onTap: onDecrease),
          SizedBox(
            width: 40,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          _SheetStepperButton(
            icon: LucideIcons.plus,
            onTap: onIncrease,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _SheetStepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool emphasized;

  const _SheetStepperButton({
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PressableScale(
      onTap: onTap,
      semanticLabel: 'Change quantity',
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: emphasized ? cs.primary : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 16,
          color: emphasized ? cs.onPrimary : cs.onSurface,
        ),
      ),
    );
  }
}
