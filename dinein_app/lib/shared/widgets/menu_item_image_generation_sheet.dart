import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:core_pkg/constants/enums.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';

class MenuItemImageGenerationDraft {
  final String name;
  final String description;
  final String category;
  final MenuItemClass itemClass;

  const MenuItemImageGenerationDraft({
    required this.name,
    required this.description,
    required this.category,
    required this.itemClass,
  });

  Map<String, dynamic> toUpdatePayload() => {
    'name': name,
    'description': description,
    'category': category,
    'class': itemClass.dbValue,
  };
}

Future<MenuItemImageGenerationDraft?> showMenuItemImageGenerationSheet({
  required BuildContext context,
  required String title,
  required String name,
  required String description,
  required String category,
  required MenuItemClass? itemClass,
  String? helperText,
}) async {
  final nameController = TextEditingController(text: name);
  final descriptionController = TextEditingController(text: description);
  final categoryController = TextEditingController(text: category);
  var selectedClass = itemClass;

  return showModalBottomSheet<MenuItemImageGenerationDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final cs = Theme.of(sheetContext).colorScheme;
          final tt = Theme.of(sheetContext).textTheme;
          final canGenerate =
              nameController.text.trim().isNotEmpty &&
              descriptionController.text.trim().isNotEmpty &&
              categoryController.text.trim().isNotEmpty &&
              selectedClass != null;

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.space4,
                AppTheme.space4,
                AppTheme.space4,
                MediaQuery.of(sheetContext).viewInsets.bottom + AppTheme.space4,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.space6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(
                            bottom: AppTheme.space4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        title,
                        style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space2),
                      Text(
                        helperText ??
                            'Review the guest-facing content first so image generation uses the right menu details.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space5),
                      _SheetTextField(
                        label: 'NAME',
                        controller: nameController,
                        hintText: 'Dry-Aged Ribeye',
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      DropdownButtonFormField<MenuItemClass>(
                        initialValue: selectedClass,
                        decoration: const InputDecoration(labelText: 'CLASS'),
                        items: MenuItemClass.values
                            .map((itemClass) {
                              return DropdownMenuItem<MenuItemClass>(
                                value: itemClass,
                                child: Text(itemClass.label),
                              );
                            })
                            .toList(growable: false),
                        onChanged: (value) =>
                            setSheetState(() => selectedClass = value),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      _SheetTextField(
                        label: 'DESCRIPTION',
                        controller: descriptionController,
                        hintText:
                            'Describe the dish, presentation, texture, and hero ingredients.',
                        maxLines: 5,
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      _SheetTextField(
                        label: 'CATEGORY',
                        controller: categoryController,
                        hintText: 'Signature Mains',
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      if (!canGenerate) ...[
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          'Add name, class, description, and category before generating the image.',
                          style: tt.bodySmall?.copyWith(color: cs.error),
                        ),
                      ],
                      const SizedBox(height: AppTheme.space5),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stackActions = constraints.maxWidth < 520;
                          final cancelButton = PremiumButton(
                            label: 'CANCEL',
                            icon: LucideIcons.x,
                            isOutlined: true,
                            isSmall: true,
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(null),
                          );
                          final generateButton = PremiumButton(
                            label: 'GENERATE IMAGE',
                            icon: LucideIcons.sparkles,
                            isSmall: true,
                            onPressed: canGenerate
                                ? () {
                                    Navigator.of(sheetContext).pop(
                                      MenuItemImageGenerationDraft(
                                        name: nameController.text.trim(),
                                        description: descriptionController.text
                                            .trim(),
                                        category: categoryController.text
                                            .trim(),
                                        itemClass: selectedClass!,
                                      ),
                                    );
                                  }
                                : null,
                          );

                          if (stackActions) {
                            return Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: generateButton,
                                ),
                                const SizedBox(height: AppTheme.space3),
                                SizedBox(
                                  width: double.infinity,
                                  child: cancelButton,
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: cancelButton),
                              const SizedBox(width: AppTheme.space3),
                              Expanded(child: generateButton),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _SheetTextField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _SheetTextField({
    required this.label,
    required this.hintText,
    required this.controller,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, hintText: hintText),
    );
  }
}
