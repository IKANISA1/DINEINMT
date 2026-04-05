import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:db_pkg/models/models.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/services/menu_repository.dart';
import 'package:dinein_app/shared/widgets/menu_item_image_generation_sheet.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

class AdminMenuReviewScreen extends ConsumerStatefulWidget {
  final String venueId;

  const AdminMenuReviewScreen({super.key, required this.venueId});

  @override
  ConsumerState<AdminMenuReviewScreen> createState() =>
      _AdminMenuReviewScreenState();
}

class _AdminMenuReviewScreenState extends ConsumerState<AdminMenuReviewScreen> {
  String? _busyItemId;

  Future<void> _editDescription(MenuItem item) async {
    final controller = TextEditingController(text: item.description);
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit ${item.name}'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'DESCRIPTION',
            hintText: 'Update the guest-facing description',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == null) return;

    setState(() => _busyItemId = item.id);
    try {
      await MenuRepository.instance.updateMenuItem(item.id, {
        'description': saved,
      }, useAdminSession: true);
      ref.invalidate(adminMenuItemsProvider(widget.venueId));
      ref.invalidate(adminMenuQueueProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu description updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update description: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyItemId = null);
      }
    }
  }

  Future<void> _generateImage(MenuItem item) async {
    final draft = await showMenuItemImageGenerationSheet(
      context: context,
      title: 'Generate Item Image',
      name: item.name,
      description: item.description,
      category: item.category,
      itemClass: item.itemClass,
      helperText:
          'Confirm the guest-facing content first so the generated image matches the item correctly.',
    );
    if (draft == null) return;

    setState(() => _busyItemId = item.id);
    try {
      await MenuRepository.instance.updateMenuItem(
        item.id,
        draft.toUpdatePayload(),
        useAdminSession: true,
      );
      await MenuRepository.instance.generateMenuItemImage(
        item.id,
        venueId: item.venueId,
        forceRegenerate: item.imageUrl != null,
        useAdminSession: true,
      );
      ref.invalidate(adminMenuItemsProvider(widget.venueId));
      ref.invalidate(adminMenuQueueProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image generation requested.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate image: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyItemId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final venueAsync = ref.watch(venueByIdProvider(widget.venueId));
    final menuAsync = ref.watch(adminMenuItemsProvider(widget.venueId));

    final venueName =
        venueAsync.whenOrNull(data: (venue) => venue?.name) ?? 'Venue';

    return Scaffold(
      appBar: AppBar(
        title: Text('Menu Review — $venueName', style: tt.headlineMedium),
      ),
      body: menuAsync.when(
        loading: () => const Center(
          child: SkeletonLoader(width: double.infinity, height: 300),
        ),
        error: (_, _) => ErrorState(
          message: 'Could not load menu items.',
          onRetry: () => ref.invalidate(adminMenuItemsProvider(widget.venueId)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.fileText,
              title: 'No menu items to review',
              subtitle: 'This venue has no menu items yet.',
            );
          }

          final categories = <String, List<MenuItem>>{};
          for (final item in items) {
            categories.putIfAbsent(item.category, () => []).add(item);
          }

          return ListView(
            padding: const EdgeInsets.all(AppTheme.space6),
            children: categories.entries
                .expand((entry) {
                  final categoryItems = entry.value;
                  return [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppTheme.space4,
                        bottom: AppTheme.space2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key.toUpperCase(),
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              letterSpacing: 3,
                            ),
                          ),
                          Text(
                            '${categoryItems.length} items',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...categoryItems.asMap().entries.map((itemEntry) {
                      final item = itemEntry.value;
                      final index = itemEntry.key;
                      final isBusy = _busyItemId == item.id;

                      return ClayCard(
                        padding: const EdgeInsets.all(AppTheme.space5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                  child: DineInImage(
                                    imageUrl: item.imageUrl,
                                    width: 64,
                                    height: 64,
                                    fallbackIcon: LucideIcons.chefHat,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.space3),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: tt.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.price.toStringAsFixed(2)} • ${item.isAvailable ? "Available" : "Unavailable"}',
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: AppTheme.space2),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          StatusBadge(
                                            label: item.isAvailable
                                                ? 'Active'
                                                : 'Hidden',
                                            color:
                                                (item.isAvailable
                                                        ? cs.secondary
                                                        : cs.error)
                                                    .withValues(alpha: 0.12),
                                            textColor: item.isAvailable
                                                ? cs.secondary
                                                : cs.error,
                                          ),
                                          if (item.adminManaged)
                                            StatusBadge(
                                              label: 'Admin managed',
                                              color: cs.primary.withValues(
                                                alpha: 0.12,
                                              ),
                                              textColor: cs.primary,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.space3),
                            Text(
                              item.description.isEmpty
                                  ? 'No description set.'
                                  : item.description,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppTheme.space3),
                            Text(
                              'Price and availability remain venue-owned. Admin can update description and trigger image generation only.',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.72,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppTheme.space4),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final stackActions = constraints.maxWidth < 520;
                                final editButton = PremiumButton(
                                  label: 'EDIT DESCRIPTION',
                                  icon: LucideIcons.pencil,
                                  isOutlined: true,
                                  isSmall: true,
                                  onPressed: isBusy
                                      ? null
                                      : () => _editDescription(item),
                                );
                                final generateButton = PremiumButton(
                                  label: 'GENERATE IMAGE',
                                  icon: LucideIcons.sparkles,
                                  isSmall: true,
                                  isLoading: isBusy,
                                  onPressed: isBusy
                                      ? null
                                      : () => _generateImage(item),
                                );

                                if (stackActions) {
                                  return Column(
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: editButton,
                                      ),
                                      const SizedBox(height: AppTheme.space3),
                                      SizedBox(
                                        width: double.infinity,
                                        child: generateButton,
                                      ),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: editButton),
                                    const SizedBox(width: AppTheme.space3),
                                    Expanded(child: generateButton),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ).animate(delay: (80 * index).ms).fadeIn(duration: 300.ms);
                    }),
                  ];
                })
                .toList(growable: false),
          );
        },
      ),
    );
  }
}
