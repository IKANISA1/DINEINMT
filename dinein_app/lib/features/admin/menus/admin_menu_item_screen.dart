import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import '../../../core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/services/menu_repository.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

part 'widgets/admin_menu_item_widgets.dart';

class AdminMenuItemScreen extends ConsumerStatefulWidget {
  final String? groupId;

  const AdminMenuItemScreen({super.key, this.groupId});

  bool get isEditing => groupId != null;

  @override
  ConsumerState<AdminMenuItemScreen> createState() =>
      _AdminMenuItemScreenState();
}

class _AdminMenuItemScreenState extends ConsumerState<AdminMenuItemScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _imageUrlController = TextEditingController();

  MenuItemClass? _selectedClass;
  bool _assignAllVenues = false;
  bool _isSaving = false;
  bool _isGenerating = false;
  bool _seeded = false;
  final Set<String> _selectedVenueIds = <String>{};

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _seedFromCatalog(AdminMenuCatalogEntry entry) {
    if (_seeded) return;
    _seeded = true;
    _nameController.text = entry.name;
    _descriptionController.text = entry.description;
    _categoryController.text = entry.category;
    _tagsController.text = entry.tags.join(', ');
    _imageUrlController.text = entry.imageSource == MenuItemImageSource.manual
        ? entry.imageUrl ?? ''
        : '';
    _selectedClass = entry.itemClass;
  }

  List<String> _parseTags() {
    return _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> _buildDraftPayload() {
    return {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _categoryController.text.trim().isEmpty
          ? 'Uncategorized'
          : _categoryController.text.trim(),
      'tags': _parseTags(),
      'class': _selectedClass?.dbValue,
      'image_url': _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
    };
  }

  Future<void> _showVenuePicker(List<Venue> venues) async {
    var assignAll = _assignAllVenues;
    final draftSelection = {..._selectedVenueIds};

    final result = await showModalBottomSheet<_VenueSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final cs = Theme.of(sheetContext).colorScheme;
            final tt = Theme.of(sheetContext).textTheme;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.space4,
                AppTheme.space4,
                AppTheme.space4,
                MediaQuery.of(sheetContext).viewInsets.bottom + AppTheme.space4,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.space6),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign Venues',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space2),
                    Text(
                      'Choose specific venues or assign this menu item to all venues in the current country.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    SwitchListTile(
                      value: assignAll,
                      onChanged: (value) =>
                          setSheetState(() => assignAll = value),
                      title: const Text('Assign to all venues'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: AppTheme.space2),
                    SizedBox(
                      height: 260,
                      child: ListView.separated(
                        itemCount: venues.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppTheme.space2),
                        itemBuilder: (context, index) {
                          final venue = venues[index];
                          final isSelected = draftSelection.contains(venue.id);
                          return Opacity(
                            opacity: assignAll ? 0.45 : 1,
                            child: CheckboxListTile(
                              value: isSelected || assignAll,
                              onChanged: assignAll
                                  ? null
                                  : (value) {
                                      setSheetState(() {
                                        if (value == true) {
                                          draftSelection.add(venue.id);
                                        } else {
                                          draftSelection.remove(venue.id);
                                        }
                                      });
                                    },
                              title: Text(venue.name),
                              subtitle: Text(
                                venue.address.isEmpty
                                    ? venue.slug
                                    : venue.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    SizedBox(
                      width: double.infinity,
                      child: PremiumButton(
                        label: 'APPLY ASSIGNMENT',
                        icon: LucideIcons.check,
                        onPressed: () {
                          Navigator.of(sheetContext).pop(
                            _VenueSelectionResult(
                              assignAll: assignAll,
                              venueIds: draftSelection.toList(growable: false),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    setState(() {
      _assignAllVenues = result.assignAll;
      _selectedVenueIds
        ..clear()
        ..addAll(result.venueIds);
    });
  }

  Future<void> _saveNew() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Menu item name is required.');
      return;
    }
    if (!_assignAllVenues && _selectedVenueIds.isEmpty) {
      _showSnack('Choose at least one venue or assign to all venues.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await MenuRepository.instance.createAdminMenuGroups(
        items: [_buildDraftPayload()],
        venueIds: _selectedVenueIds.toList(growable: false),
        assignAll: _assignAllVenues,
      );
      ref.invalidate(adminMenuCatalogProvider);
      ref.invalidate(adminMenuQueueProvider);
      if (!mounted) return;
      _showSnack('Admin menu item created.');
      context.goNamed(AppRouteNames.adminMenus);
    } catch (error) {
      _showSnack('Could not create menu item: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveExisting(AdminMenuCatalogEntry entry) async {
    setState(() => _isSaving = true);
    try {
      await MenuRepository.instance.updateMenuItem(
        entry.representativeItemId,
        _buildDraftPayload(),
        useAdminSession: true,
      );
      ref.invalidate(adminMenuCatalogProvider);
      ref.invalidate(adminMenuGroupAssignmentsProvider(entry.groupId));
      if (!mounted) return;
      _showSnack('Shared menu content updated.');
    } catch (error) {
      _showSnack('Could not update menu item: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _assignMore(AdminMenuCatalogEntry entry) async {
    if (!_assignAllVenues && _selectedVenueIds.isEmpty) {
      _showSnack('Choose at least one venue or assign to all venues.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await MenuRepository.instance.assignAdminMenuGroup(
        entry.groupId,
        venueIds: _selectedVenueIds.toList(growable: false),
        assignAll: _assignAllVenues,
      );
      ref.invalidate(adminMenuCatalogProvider);
      ref.invalidate(adminMenuGroupAssignmentsProvider(entry.groupId));
      if (!mounted) return;
      _showSnack('Menu item assigned to venues.');
      setState(() {
        _assignAllVenues = false;
        _selectedVenueIds.clear();
      });
    } catch (error) {
      _showSnack('Could not assign venues: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _generateImage(AdminMenuCatalogEntry entry) async {
    setState(() => _isGenerating = true);
    try {
      await MenuRepository.instance.generateMenuItemImage(
        entry.representativeItemId,
        venueId: entry.representativeVenueId,
        forceRegenerate: entry.imageUrl != null,
        useAdminSession: true,
      );
      ref.invalidate(adminMenuCatalogProvider);
      ref.invalidate(adminMenuGroupAssignmentsProvider(entry.groupId));
      if (!mounted) return;
      _showSnack('Image generation requested.');
    } catch (error) {
      _showSnack('Could not generate image: $error');
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _delete(AdminMenuCatalogEntry entry) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete menu item'),
            content: Text('Remove "${entry.name}" from all assigned venues?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _isSaving = true);
    try {
      await MenuRepository.instance.deleteAdminMenuGroup(entry.groupId);
      ref.invalidate(adminMenuCatalogProvider);
      ref.invalidate(adminMenuQueueProvider);
      if (!mounted) return;
      context.goNamed(AppRouteNames.adminMenus);
      _showSnack('Admin menu item deleted.');
    } catch (error) {
      _showSnack('Could not delete menu item: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final venuesAsync = ref.watch(allVenuesProvider);

    if (!widget.isEditing) {
      return venuesAsync.when(
        loading: () => const Scaffold(
          body: Center(
            child: SkeletonLoader(width: double.infinity, height: 320),
          ),
        ),
        error: (error, _) => Scaffold(
          body: ErrorState(
            message: 'Could not load venues.',
            onRetry: () => ref.invalidate(allVenuesProvider),
          ),
        ),
        data: (venues) => _buildScaffold(
          context,
          venues: venues,
          entry: null,
          assignments: const [],
        ),
      );
    }

    final catalogAsync = ref.watch(adminMenuCatalogProvider);
    return catalogAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: SkeletonLoader(width: double.infinity, height: 320),
        ),
      ),
      error: (error, _) => Scaffold(
        body: ErrorState(
          message: 'Could not load the admin menu item.',
          onRetry: () => ref.invalidate(adminMenuCatalogProvider),
        ),
      ),
      data: (catalog) {
        AdminMenuCatalogEntry? entry;
        for (final candidate in catalog) {
          if (candidate.groupId == widget.groupId) {
            entry = candidate;
            break;
          }
        }
        if (entry == null) {
          return const Scaffold(
            body: EmptyState(
              icon: LucideIcons.fileQuestion,
              title: 'Menu item not found',
              subtitle: 'The selected admin menu item could not be loaded.',
            ),
          );
        }
        _seedFromCatalog(entry);
        final assignmentsAsync = ref.watch(
          adminMenuGroupAssignmentsProvider(entry.groupId),
        );
        return venuesAsync.when(
          loading: () => const Scaffold(
            body: Center(
              child: SkeletonLoader(width: double.infinity, height: 320),
            ),
          ),
          error: (error, _) => Scaffold(
            body: ErrorState(
              message: 'Could not load venues.',
              onRetry: () => ref.invalidate(allVenuesProvider),
            ),
          ),
          data: (venues) => assignmentsAsync.when(
            loading: () => _buildScaffold(
              context,
              venues: venues,
              entry: entry,
              assignments: const [],
              isAssignmentsLoading: true,
            ),
            error: (error, _) => _buildScaffold(
              context,
              venues: venues,
              entry: entry,
              assignments: const [],
            ),
            data: (assignments) => _buildScaffold(
              context,
              venues: venues,
              entry: entry,
              assignments: assignments,
            ),
          ),
        );
      },
    );
  }

  Scaffold _buildScaffold(
    BuildContext context, {
    required List<Venue> venues,
    required AdminMenuCatalogEntry? entry,
    required List<AdminMenuGroupAssignment> assignments,
    bool isAssignmentsLoading = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space6,
                AppTheme.space6,
                AppTheme.space6,
                160,
              ),
              children: [
                Row(
                  children: [
                    PressableScale(
                      onTap: () => context.goNamed(AppRouteNames.adminMenus),
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
                            widget.isEditing
                                ? 'Admin Menu Item'
                                : 'New Menu Item',
                            style: tt.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            widget.isEditing
                                ? 'CENTRAL MENU MANAGEMENT'
                                : 'CREATE AND ASSIGN',
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
                const SizedBox(height: AppTheme.space6),
                ClayCard(
                  padding: const EdgeInsets.all(AppTheme.space5),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        child: SizedBox(
                          width: 84,
                          height: 84,
                          child: DineInImage(
                            imageUrl: _imageUrlController.text.trim().isNotEmpty
                                ? _imageUrlController.text.trim()
                                : entry?.imageUrl,
                            fit: BoxFit.cover,
                            fallbackIcon: LucideIcons.chefHat,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nameController.text.trim().isEmpty
                                  ? 'Menu item preview'
                                  : _nameController.text.trim(),
                              style: tt.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _categoryController.text.trim().isEmpty
                                  ? 'Uncategorized'
                                  : _categoryController.text.trim(),
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppTheme.space2),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_selectedClass != null)
                                  StatusBadge(
                                    label: _selectedClass!.label,
                                    color: cs.primary.withValues(alpha: 0.12),
                                    textColor: cs.primary,
                                  ),
                                if (widget.isEditing)
                                  StatusBadge(
                                    label:
                                        '${assignments.length} assigned venue${assignments.length == 1 ? '' : 's'}',
                                    color: cs.secondary.withValues(alpha: 0.12),
                                    textColor: cs.secondary,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                _FieldCard(
                  title: 'Core Content',
                  children: [
                    _TextFieldBlock(
                      label: 'NAME',
                      controller: _nameController,
                      hint: 'Cheeseburger',
                    ),
                    _TextFieldBlock(
                      label: 'DESCRIPTION',
                      controller: _descriptionController,
                      hint: 'Short description shown across assigned venues',
                      maxLines: 4,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _TextFieldBlock(
                            label: 'CATEGORY',
                            controller: _categoryController,
                            hint: 'Mains',
                          ),
                        ),
                        const SizedBox(width: AppTheme.space4),
                        Expanded(
                          child: _ClassDropdown(
                            value: _selectedClass,
                            onChanged: (value) =>
                                setState(() => _selectedClass = value),
                          ),
                        ),
                      ],
                    ),
                    _TextFieldBlock(
                      label: 'TAGS',
                      controller: _tagsController,
                      hint: 'Signature, Vegan, Spicy',
                    ),
                    _TextFieldBlock(
                      label: 'MANUAL IMAGE URL',
                      controller: _imageUrlController,
                      hint: 'https://images.example.com/menu-item.jpg',
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space4),
                _FieldCard(
                  title: widget.isEditing
                      ? 'Venue Assignment'
                      : 'Assign To Venues',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _assignAllVenues
                                ? 'This action will apply to all venues in the current country.'
                                : _selectedVenueIds.isEmpty
                                ? widget.isEditing
                                      ? 'Choose venues to add this item to.'
                                      : 'Choose one or more venues for this item.'
                                : '${_selectedVenueIds.length} venue${_selectedVenueIds.length == 1 ? '' : 's'} selected for the next assignment.',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.space4),
                        PremiumButton(
                          label: 'SELECT',
                          icon: LucideIcons.store,
                          isOutlined: true,
                          isSmall: true,
                          onPressed: () => _showVenuePicker(venues),
                        ),
                      ],
                    ),
                    if (widget.isEditing) ...[
                      const SizedBox(height: AppTheme.space4),
                      if (isAssignmentsLoading)
                        const SkeletonLoader(
                          width: double.infinity,
                          height: 120,
                        )
                      else if (assignments.isEmpty)
                        const EmptyState(
                          icon: LucideIcons.store,
                          title: 'No venue assignments',
                          subtitle: 'Assign this item to one or more venues.',
                        )
                      else
                        ...assignments.map(
                          (assignment) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppTheme.space2,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(AppTheme.space4),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainer,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLg,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          assignment.venueName,
                                          style: tt.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          assignment.venueSlug,
                                          style: tt.bodySmall?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusBadge(
                                    label: assignment.isAvailable
                                        ? 'Live'
                                        : assignment.price <= 0
                                        ? 'Needs Price'
                                        : 'Draft',
                                    color: assignment.isAvailable
                                        ? cs.secondary.withValues(alpha: 0.12)
                                        : cs.tertiary.withValues(alpha: 0.12),
                                    textColor: assignment.isAvailable
                                        ? cs.secondary
                                        : cs.tertiary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
                if (widget.isEditing && entry != null) ...[
                  const SizedBox(height: AppTheme.space4),
                  _FieldCard(
                    title: 'Image Automation',
                    children: [
                      Text(
                        'Admin can trigger menu image generation across all assigned venues from the representative menu item.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Row(
                        children: [
                          Expanded(
                            child: PremiumButton(
                              label: 'GENERATE IMAGE',
                              icon: LucideIcons.sparkles,
                              isOutlined: true,
                              onPressed: _isGenerating
                                  ? null
                                  : () => _generateImage(entry),
                              isLoading: _isGenerating,
                            ),
                          ),
                          const SizedBox(width: AppTheme.space3),
                          Expanded(
                            child: PremiumButton(
                              label: 'DELETE ITEM',
                              icon: LucideIcons.trash2,
                              isOutlined: true,
                              onPressed: _isSaving
                                  ? null
                                  : () => _delete(entry),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
            Positioned(
              left: AppTheme.space6,
              right: AppTheme.space6,
              bottom: 100,
              child: Row(
                children: [
                  if (widget.isEditing && entry != null) ...[
                    Expanded(
                      child: PremiumButton(
                        label: 'ASSIGN VENUES',
                        icon: LucideIcons.store,
                        isOutlined: true,
                        onPressed: _isSaving ? null : () => _assignMore(entry),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space3),
                  ],
                  Expanded(
                    child: PremiumButton(
                      label: widget.isEditing ? 'SAVE CHANGES' : 'CREATE ITEM',
                      icon: LucideIcons.save,
                      isLoading: _isSaving,
                      onPressed: _isSaving
                          ? null
                          : () => widget.isEditing && entry != null
                                ? _saveExisting(entry)
                                : _saveNew(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

