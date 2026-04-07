import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/services/image_upload_service.dart';
import 'package:dinein_app/core/services/menu_repository.dart';
import 'package:dinein_app/shared/widgets/menu_item_image_generation_sheet.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

/// Menu item editor for venue owners.
///
/// Supports both creation and editing from the venue menu manager flow.
class VenueEditItemScreen extends ConsumerStatefulWidget {
  final String? itemId;

  const VenueEditItemScreen({super.key, this.itemId});

  bool get isEditing => itemId != null;

  @override
  ConsumerState<VenueEditItemScreen> createState() =>
      _VenueEditItemScreenState();
}

class _VenueEditItemScreenState extends ConsumerState<VenueEditItemScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _imageUrlController = TextEditingController();

  MenuItemClass? _selectedClass;
  bool _isAvailable = true;
  bool _isSaving = false;
  bool _isGeneratingImage = false;
  bool _isUploadingImage = false;
  bool _isUpdatingImageLock = false;
  String? _seededItemId;
  String? _error;
  Timer? _imageStatusPoller;
  MenuItemImageStatus? _lastPolledStatus;

  @override
  void dispose() {
    _imageStatusPoller?.cancel();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _maybeStartImagePolling(MenuItem? item, Venue? venue) {
    if (item == null || venue == null) {
      _imageStatusPoller?.cancel();
      _imageStatusPoller = null;
      return;
    }

    final status = item.effectiveImageStatus;

    // Notify on transition from generating → ready.
    if (_lastPolledStatus == MenuItemImageStatus.generating &&
        status == MenuItemImageStatus.ready &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image ready for ${item.name}.')));
    }
    _lastPolledStatus = status;

    if (status == MenuItemImageStatus.generating) {
      if (_imageStatusPoller?.isActive == true) return;
      _imageStatusPoller = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted) {
          _imageStatusPoller?.cancel();
          return;
        }
        ref.invalidate(menuItemsProvider(venue.id));
      });
    } else {
      _imageStatusPoller?.cancel();
      _imageStatusPoller = null;
    }
  }

  void _seedForm(MenuItem? item) {
    if (item == null || _seededItemId == item.id) return;

    _seededItemId = item.id;
    _nameController.text = item.name;
    _descriptionController.text = item.description;
    _priceController.text = item.price.toStringAsFixed(2);
    _categoryController.text = item.category;
    _tagsController.text = item.tags.join(', ');
    _imageUrlController.text =
        item.effectiveImageSource == MenuItemImageSource.manual
        ? item.imageUrl ?? ''
        : '';
    _selectedClass = item.itemClass;
    _isAvailable = item.isAvailable;
  }

  List<String> _parseTags() {
    return _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  bool _isSupportedImageUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    if (uri.data != null) return true;
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'https' || scheme == 'http') && uri.host.isNotEmpty;
  }

  String? _manualImageUrl(MenuItem? existing) {
    final raw = _imageUrlController.text.trim();
    if (raw.isEmpty) {
      if (existing?.effectiveImageSource == MenuItemImageSource.manual) {
        return existing?.imageUrl;
      }
      return null;
    }
    return raw;
  }

  String? _previewImageUrl(MenuItem? existing) {
    final draftUrl = _imageUrlController.text.trim();
    if (draftUrl.isNotEmpty) return draftUrl;
    return existing?.imageUrl;
  }

  Future<void> _save(Venue venue, MenuItem? existing) async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final category = _categoryController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final rawManualImageUrl = _imageUrlController.text.trim();

    if (name.isEmpty || category.isEmpty || price == null) {
      setState(() {
        _error = 'Name, category, and a valid price are required.';
      });
      return;
    }

    if (rawManualImageUrl.isNotEmpty &&
        !_isSupportedImageUrl(rawManualImageUrl)) {
      setState(() {
        _error = 'Add a valid image URL or inline data image before saving.';
      });
      return;
    }

    final manualImageUrl = _manualImageUrl(existing);

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      MenuItem? savedItem;
      if (existing == null) {
        savedItem = await MenuRepository.instance.createMenuItem(
          MenuItem(
            id: '',
            venueId: venue.id,
            name: name,
            description: description,
            price: price,
            category: category,
            itemClass: _selectedClass,
            imageUrl: manualImageUrl,
            imageSource: manualImageUrl != null
                ? MenuItemImageSource.manual
                : MenuItemImageSource.unknown,
            imageStatus: manualImageUrl != null
                ? MenuItemImageStatus.ready
                : MenuItemImageStatus.pending,
            imageLocked: manualImageUrl != null,
            isAvailable: _isAvailable,
            tags: _parseTags(),
          ),
        );
      } else {
        final updates = <String, dynamic>{
          'name': name,
          'description': description,
          'price': price,
          'category': category,
          'class': _selectedClass?.dbValue,
          'is_available': _isAvailable,
          'tags': _parseTags(),
        };

        final shouldApplyManualImage =
            manualImageUrl != null &&
            (existing.imageUrl != manualImageUrl ||
                existing.effectiveImageSource != MenuItemImageSource.manual ||
                existing.effectiveImageStatus != MenuItemImageStatus.ready ||
                !existing.imageLocked);

        if (shouldApplyManualImage) {
          updates.addAll({
            'image_url': manualImageUrl,
            'image_source': MenuItemImageSource.manual.dbValue,
            'image_status': MenuItemImageStatus.ready.dbValue,
            'image_model': null,
            'image_prompt': null,
            'image_error': null,
            'image_generated_at': null,
            'image_storage_path': null,
            'image_locked': true,
          });
        } else {
          updates['image_locked'] = existing.imageLocked;
        }

        await MenuRepository.instance.updateMenuItem(existing.id, updates);
        savedItem = existing.copyWith(
          name: name,
          description: description,
          price: price,
          category: category,
          itemClass: _selectedClass,
          imageUrl: manualImageUrl,
          imageSource: manualImageUrl != null
              ? MenuItemImageSource.manual
              : existing.imageSource,
          imageStatus: manualImageUrl != null
              ? MenuItemImageStatus.ready
              : existing.imageStatus,
          imageModel: manualImageUrl != null ? null : existing.imageModel,
          imageError: manualImageUrl != null ? null : existing.imageError,
          imageGeneratedAt: manualImageUrl != null
              ? null
              : existing.imageGeneratedAt,
          imageLocked: manualImageUrl != null ? true : existing.imageLocked,
          isAvailable: _isAvailable,
          tags: _parseTags(),
        );
      }

      if (existing != null && savedItem.needsGeneratedImage) {
        unawaited(MenuRepository.instance.generateMenuItemImage(
          savedItem.id,
          venueId: venue.id,
        ));
      }

      ref.invalidate(menuItemsProvider(venue.id));
      if (mounted) {
        context.pop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Unable to save the menu item right now.';
      });
    }
  }

  Future<void> _uploadMenuItemImage(Venue venue, MenuItem existing) async {
    if (_isUploadingImage) return;
    setState(() => _isUploadingImage = true);
    try {
      final url = await ImageUploadService.instance
          .pickAndUploadMenuItemImage(venue.id, existing.id);
      if (url == null) {
        // User cancelled the picker
        return;
      }
      // Update local controller so preview refreshes immediately
      setState(() => _imageUrlController.text = url);
      ref.invalidate(menuItemsProvider(venue.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu item image uploaded.')),
      );
    } on ImageUploadException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload item image.')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _generateImage(Venue venue, MenuItem existing) async {
    final draft = await showMenuItemImageGenerationSheet(
      context: context,
      title: 'Generate Item Image',
      name: _nameController.text.trim().isEmpty
          ? existing.name
          : _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? existing.description
          : _descriptionController.text.trim(),
      category: _categoryController.text.trim().isEmpty
          ? existing.category
          : _categoryController.text.trim(),
      itemClass: _selectedClass ?? existing.itemClass,
      helperText:
          'Review the guest-facing details first so automatic image generation picks up the right menu information.',
    );
    if (draft == null) return;

    setState(() {
      _nameController.text = draft.name;
      _descriptionController.text = draft.description;
      _categoryController.text = draft.category;
      _selectedClass = draft.itemClass;
      _isGeneratingImage = true;
      _error = null;
    });

    try {
      await MenuRepository.instance.updateMenuItem(
        existing.id,
        draft.toUpdatePayload(),
      );
      final result = await MenuRepository.instance.generateMenuItemImage(
        existing.id,
        venueId: venue.id,
        forceRegenerate: existing.hasImage,
      );
      ref.invalidate(menuItemsProvider(venue.id));
      if (!mounted) return;
      final message = switch (result.status) {
        'success' =>
          result.imageUrl != null
              ? 'Image updated for ${existing.name}.'
              : 'Image generated for ${existing.name}.',
        'skipped' => switch (result.reason) {
          'image_locked' =>
            '${existing.name} is protected from automatic changes.',
          'manual_image_exists' =>
            '${existing.name} already uses a manual image.',
          'already_generating' =>
            'Image generation is already running for ${existing.name}.',
          _ => 'No automatic image change was needed for ${existing.name}.',
        },
        _ => 'Image request completed for ${existing.name}.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to generate an image right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingImage = false;
        });
      }
    }
  }

  Future<void> _setImageLock(
    Venue venue,
    MenuItem existing,
    bool locked,
  ) async {
    setState(() {
      _isUpdatingImageLock = true;
      _error = null;
    });

    try {
      await MenuRepository.instance.setMenuItemImageLock(existing.id, locked);
      ref.invalidate(menuItemsProvider(venue.id));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to update the image protection setting.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingImageLock = false;
        });
      }
    }
  }

  Future<void> _delete(Venue venue, MenuItem existing) async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await MenuRepository.instance.deleteMenuItem(existing.id);
      ref.invalidate(menuItemsProvider(venue.id));
      if (mounted) {
        context.pop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Unable to delete this menu item right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentVenueAsync = ref.watch(currentVenueProvider);

    return Scaffold(
      body: currentVenueAsync.when(
        loading: () => const Center(
          child: SkeletonLoader(width: double.infinity, height: 320),
        ),
        error: (_, _) => ErrorState(
          message: 'Could not load your venue context.',
          onRetry: () => ref.invalidate(currentVenueProvider),
        ),
        data: (venue) {
          if (venue == null) {
            return const EmptyState(
              icon: LucideIcons.store,
              title: 'No venue selected',
              subtitle: 'Sign in as a venue owner to manage menu items.',
            );
          }

          if (!widget.isEditing) {
            return _buildForm(context, venue, null);
          }

          final itemAsync = ref.watch(menuItemsProvider(venue.id));
          return itemAsync.when(
            loading: () => const Center(
              child: SkeletonLoader(width: double.infinity, height: 320),
            ),
            error: (_, _) => ErrorState(
              message: 'Could not load this menu item.',
              onRetry: () => ref.invalidate(menuItemsProvider(venue.id)),
            ),
            data: (items) {
              final existing = items
                  .where((item) => item.id == widget.itemId)
                  .firstOrNull;

              if (existing == null) {
                return const EmptyState(
                  icon: LucideIcons.utensils,
                  title: 'Menu item not found',
                  subtitle: 'The selected item could not be found.',
                );
              }

              _maybeStartImagePolling(existing, venue);
              return _buildForm(context, venue, existing);
            },
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, Venue venue, MenuItem? existing) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    _seedForm(existing);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.space6),
        children: [
          Row(
            children: [
              PressableScale(
                onTap: () => context.pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(LucideIcons.chevronLeft, color: cs.onSurface),
                ),
              ),
              const SizedBox(width: AppTheme.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEditing ? 'Edit Menu Item' : 'New Menu Item',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      venue.name,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space6),
          _ImagePanel(
            item: existing,
            displayImageUrl: _previewImageUrl(existing),
            imageUrlController: _imageUrlController,
            isGeneratingImage: _isGeneratingImage,
            isUploadingImage: _isUploadingImage,
            isUpdatingImageLock: _isUpdatingImageLock,
            onImageUrlChanged: (_) {
              if (_error == null) {
                setState(() {});
                return;
              }
              setState(() {
                _error = null;
              });
            },
            onUpload: existing == null
                ? null
                : () => _uploadMenuItemImage(venue, existing),
            onGenerate: existing == null
                ? null
                : () => _generateImage(venue, existing),
            onToggleLock: existing == null
                ? null
                : (value) => _setImageLock(venue, existing, value),
          ),
          const SizedBox(height: AppTheme.space6),
          ClayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Item name',
                    hintText: 'Dry-Aged Ribeye',
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  minLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe the dish, preparation, and highlights.',
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackFields = constraints.maxWidth < 640;
                    final priceField = TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        hintText: '48.00',
                      ),
                    );
                    final categoryField = TextField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText: 'Signature Mains',
                      ),
                    );
                    final classField = DropdownButtonFormField<MenuItemClass>(
                      initialValue: _selectedClass,
                      decoration: const InputDecoration(labelText: 'Class'),
                      items: MenuItemClass.values
                          .map((itemClass) {
                            return DropdownMenuItem<MenuItemClass>(
                              value: itemClass,
                              child: Text(itemClass.label),
                            );
                          })
                          .toList(growable: false),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() => _selectedClass = value);
                            },
                    );

                    if (stackFields) {
                      return Column(
                        children: [
                          priceField,
                          const SizedBox(height: AppTheme.space4),
                          categoryField,
                          const SizedBox(height: AppTheme.space4),
                          classField,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: priceField),
                        const SizedBox(width: AppTheme.space4),
                        Expanded(child: categoryField),
                        const SizedBox(width: AppTheme.space4),
                        Expanded(child: classField),
                      ],
                    );
                  },
                ),
                // Tags
                TextField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                    hintText: 'Vegetarian, Spicy',
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isAvailable,
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _isAvailable = value),
                  title: Text('Available for ordering', style: tt.titleSmall),
                  subtitle: Text(
                    'Hide this item if it is out of stock.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppTheme.space3),
                  Text(_error!, style: tt.bodySmall?.copyWith(color: cs.error)),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space6),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackActions = constraints.maxWidth < 560;
              final deleteButton = existing != null
                  ? PremiumButton(
                      label: 'DELETE',
                      isOutlined: true,
                      isLoading: _isSaving,
                      onPressed: () => _delete(venue, existing),
                      icon: LucideIcons.trash2,
                    )
                  : null;
              final saveButton = PremiumButton(
                label: widget.isEditing ? 'SAVE CHANGES' : 'CREATE ITEM',
                isLoading: _isSaving,
                onPressed: () => _save(venue, existing),
                icon: LucideIcons.chevronRight,
              );

              if (stackActions) {
                return Column(
                  children: [
                    if (deleteButton != null) ...[
                      SizedBox(width: double.infinity, child: deleteButton),
                      const SizedBox(height: AppTheme.space4),
                    ],
                    SizedBox(width: double.infinity, child: saveButton),
                  ],
                );
              }

              return Row(
                children: [
                  if (deleteButton != null) ...[
                    Expanded(child: deleteButton),
                    const SizedBox(width: AppTheme.space4),
                  ],
                  Expanded(child: saveButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ImagePanel extends StatelessWidget {
  final MenuItem? item;
  final String? displayImageUrl;
  final TextEditingController imageUrlController;
  final bool isGeneratingImage;
  final bool isUploadingImage;
  final bool isUpdatingImageLock;
  final ValueChanged<String>? onImageUrlChanged;
  final VoidCallback? onUpload;
  final VoidCallback? onGenerate;
  final ValueChanged<bool>? onToggleLock;

  const _ImagePanel({
    required this.item,
    required this.displayImageUrl,
    required this.imageUrlController,
    required this.isGeneratingImage,
    required this.isUploadingImage,
    required this.isUpdatingImageLock,
    required this.onImageUrlChanged,
    required this.onUpload,
    required this.onGenerate,
    required this.onToggleLock,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasExistingItem = item != null;
    final status = item?.effectiveImageStatus ?? MenuItemImageStatus.pending;
    final source = item?.effectiveImageSource;
    final usesManualImage =
        item?.hasImage == true && source == MenuItemImageSource.manual;
    final statusColor = switch (status) {
      MenuItemImageStatus.ready => cs.secondary,
      MenuItemImageStatus.generating => cs.tertiary,
      MenuItemImageStatus.failed => cs.error,
      MenuItemImageStatus.pending => cs.primary,
    };
    final isBusy =
        isGeneratingImage || isUploadingImage || isUpdatingImageLock;

    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DineInImage(
                    imageUrl: displayImageUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: LucideIcons.sparkles,
                  ),
                  // Upload progress overlay
                  if (isUploadingImage)
                    Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Uploading...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: AppTheme.space4,
                    right: AppTheme.space4,
                    bottom: AppTheme.space4,
                    child: Wrap(
                      spacing: AppTheme.space2,
                      runSpacing: AppTheme.space2,
                      children: [
                        StatusBadge(
                          label: status.label,
                          color: statusColor.withValues(alpha: 0.16),
                          textColor: statusColor,
                        ),
                        if (source != null)
                          StatusBadge(
                            label: source.label,
                            color: cs.surface.withValues(alpha: 0.72),
                            textColor: cs.onSurface,
                          ),
                        if (item?.imageLocked == true)
                          StatusBadge(
                            label: 'Protected',
                            color: cs.surface.withValues(alpha: 0.72),
                            textColor: cs.onSurface,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space5),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menu Image',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Upload a photo or generate with AI.',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              // Upload icon button
              _ImageActionButton(
                icon: LucideIcons.upload,
                tooltip: 'Upload image',
                isLoading: isUploadingImage,
                onTap: isBusy
                    ? null
                    : hasExistingItem
                        ? onUpload
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Save the item first, then upload an image.',
                                ),
                              ),
                            );
                          },
              ),
              const SizedBox(width: AppTheme.space2),
              // AI Generate icon button
              _ImageActionButton(
                icon: LucideIcons.sparkles,
                tooltip: usesManualImage
                    ? 'Manual image active'
                    : 'Generate image with AI',
                isLoading: isGeneratingImage,
                onTap: isBusy || usesManualImage
                    ? null
                    : hasExistingItem
                        ? onGenerate
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Save the item first, then generate an image.',
                                ),
                              ),
                            );
                          },
              ),
            ],
          ),
          if (item?.imageError != null &&
              item!.imageError!.trim().isNotEmpty) ...[
            const SizedBox(height: AppTheme.space3),
            Text(
              item!.imageError!,
              style: tt.bodySmall?.copyWith(color: cs.error),
            ),
          ],
          if (hasExistingItem && !usesManualImage) ...[
            const SizedBox(height: AppTheme.space4),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: item!.imageLocked,
              onChanged: isBusy ? null : onToggleLock,
              title: Text('Protect current image', style: tt.titleSmall),
              subtitle: Text(
                'When enabled, automatic backfills will skip this item.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact 44×44 icon button used for upload / generate image actions.
class _ImageActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ImageActionButton({
    required this.icon,
    required this.tooltip,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDisabled = onTap == null && !isLoading;

    return Tooltip(
      message: tooltip,
      child: PressableScale(
        onTap: isLoading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDisabled
                ? cs.surfaceContainerHigh.withValues(alpha: 0.4)
                : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isDisabled
                  ? cs.outline.withValues(alpha: 0.1)
                  : cs.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                : Icon(
                    icon,
                    size: 20,
                    color: isDisabled
                        ? cs.onSurface.withValues(alpha: 0.3)
                        : cs.onSurface,
                  ),
          ),
        ),
      ),
    );
  }
}
