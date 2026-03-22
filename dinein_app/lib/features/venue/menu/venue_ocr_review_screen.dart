import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/config/country_runtime.dart';
import '../../../core/models/onboarding_draft_models.dart';
import '../../../core/services/menu_repository.dart';
import '../../../core/services/onboarding_draft_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// OCR menu review flow used by venue onboarding and menu management.
class VenueOcrReviewScreen extends StatefulWidget {
  final bool manualMode;
  final String source;
  final String? venueId;

  const VenueOcrReviewScreen({
    super.key,
    this.manualMode = false,
    this.source = 'onboarding',
    this.venueId,
  });

  @override
  State<VenueOcrReviewScreen> createState() => _VenueOcrReviewScreenState();
}

class _VenueOcrReviewScreenState extends State<VenueOcrReviewScreen> {
  bool _isProcessing = false;
  bool _isSaving = false;
  List<OcrDraftMenuItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final existingItems = await OnboardingDraftService.loadMenuDraftItems();
    if (widget.manualMode) {
      if (!mounted) return;
      setState(() {
        _items = existingItems;
      });
      return;
    }

    if (existingItems.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _items = existingItems;
      });
      return;
    }

    if (!mounted) return;
    // No OCR simulation — start with empty menu; user adds items manually
    setState(() {
      _items = const [];
      _isProcessing = false;
    });
  }

  Future<void> _saveAndClose() async {
    setState(() => _isSaving = true);
    await OnboardingDraftService.saveMenuDraftItems(_items);

    if (widget.venueId != null && _items.isNotEmpty) {
      await MenuRepository.instance.importDraftItems(widget.venueId!, _items);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.venueId != null
              ? 'Menu items imported into your venue.'
              : 'Menu draft saved.',
        ),
      ),
    );
    context.pop(true);
  }

  Future<void> _showEditor({int? index}) async {
    final existing = index == null ? null : _items[index];
    final result = await showModalBottomSheet<OcrDraftMenuItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DraftItemEditor(item: existing),
    );

    if (result == null || !mounted) return;

    setState(() {
      final items = [..._items];
      if (index == null) {
        items.insert(0, result);
      } else {
        items[index] = result;
      }
      _items = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_isProcessing) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radius3xl),
                    ),
                    child: Icon(
                      LucideIcons.sparkles,
                      size: 48,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  Text('Building Menu Draft', style: tt.headlineMedium),
                  const SizedBox(height: AppTheme.space3),
                  Text(
                    'OCR is extracting menu items and preparing them for review.',
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: AppColors.white5),
                      ),
                      child: const Icon(LucideIcons.chevronLeft, size: 24),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.manualMode
                              ? 'MANUAL ENTRY'
                              : 'MENU EXTRACTION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: cs.primary,
                          ),
                        ),
                        Text(
                          widget.manualMode ? 'Add Menu Items' : 'Review Menu',
                          style: tt.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _items.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _items = _items
                                  .map(
                                    (item) =>
                                        item.copyWith(requiresReview: false),
                                  )
                                  .toList();
                            });
                          },
                    child: const Text('APPROVE ALL'),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space8),
              if (_items.isEmpty)
                Expanded(
                  child: EmptyState(
                    icon: widget.manualMode
                        ? LucideIcons.fileText
                        : LucideIcons.scanLine,
                    title: widget.manualMode
                        ? 'No manual items yet'
                        : 'No items extracted yet',
                    subtitle: widget.manualMode
                        ? 'Add your first item to build the draft menu.'
                        : 'Run OCR again or switch to manual entry.',
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.space3),
                        child: Container(
                          padding: const EdgeInsets.all(AppTheme.space5),
                          decoration: BoxDecoration(
                            color: item.requiresReview
                                ? cs.secondary.withValues(alpha: 0.08)
                                : cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusXl,
                            ),
                            border: Border.all(
                              color: item.requiresReview
                                  ? cs.secondary.withValues(alpha: 0.18)
                                  : AppColors.white5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item.category.toUpperCase(),
                                          style: tt.labelSmall?.copyWith(
                                            color: cs.primary,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                        if (item.requiresReview) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cs.secondary,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'REVIEW',
                                              style: tt.labelSmall?.copyWith(
                                                color: cs.onSecondary,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(item.name, style: tt.titleMedium),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.description,
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${CountryRuntime.config.country.currencySymbol}${item.price.toStringAsFixed(2)}',
                                      style: tt.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppTheme.space4),
                              Column(
                                children: [
                                  IconButton(
                                    onPressed: () => _showEditor(index: index),
                                    icon: const Icon(LucideIcons.pencil),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        final items = [..._items];
                                        items.removeAt(index);
                                        _items = items;
                                      });
                                    },
                                    icon: Icon(
                                      LucideIcons.trash2,
                                      color: cs.error,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppTheme.space4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showEditor(),
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('ADD MANUAL ITEM'),
                ),
              ),
              const SizedBox(height: AppTheme.space3),
              SizedBox(
                width: double.infinity,
                child: PremiumButton(
                  label: widget.venueId != null
                      ? 'CONFIRM & IMPORT TO MENU'
                      : 'CONFIRM & SAVE DRAFT',
                  isLoading: _isSaving,
                  onPressed: _saveAndClose,
                  icon: LucideIcons.check,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftItemEditor extends StatefulWidget {
  final OcrDraftMenuItem? item;

  const _DraftItemEditor({this.item});

  @override
  State<_DraftItemEditor> createState() => _DraftItemEditorState();
}

class _DraftItemEditorState extends State<_DraftItemEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _categoryController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.item?.description ?? '',
    );
    _priceController = TextEditingController(
      text: widget.item?.price.toStringAsFixed(2) ?? '0.00',
    );
    _categoryController = TextEditingController(
      text: widget.item?.category ?? 'General',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.space6,
        right: AppTheme.space6,
        top: AppTheme.space6,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.space6,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item == null ? 'Add Item' : 'Edit Item',
              style: tt.headlineSmall,
            ),
            const SizedBox(height: AppTheme.space6),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'Item name'),
            ),
            const SizedBox(height: AppTheme.space4),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Description'),
            ),
            const SizedBox(height: AppTheme.space4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(hintText: 'Price'),
                  ),
                ),
                const SizedBox(width: AppTheme.space4),
                Expanded(
                  child: TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(hintText: 'Category'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: AppTheme.space4),
                Expanded(
                  child: PremiumButton(
                    label: 'SAVE',
                    onPressed: () {
                      final price =
                          double.tryParse(_priceController.text.trim()) ?? 0;
                      context.pop(
                        OcrDraftMenuItem(
                          name: _nameController.text.trim(),
                          description: _descriptionController.text.trim(),
                          price: price,
                          category: _categoryController.text.trim().isEmpty
                              ? 'General'
                              : _categoryController.text.trim(),
                          tags: widget.item?.tags ?? const [],
                          requiresReview: false,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
