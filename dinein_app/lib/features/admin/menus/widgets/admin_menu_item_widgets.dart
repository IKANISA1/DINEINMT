part of '../admin_menu_item_screen.dart';
class AdminMenuCsvImportAction extends ConsumerStatefulWidget {
  const AdminMenuCsvImportAction({super.key});

  @override
  ConsumerState<AdminMenuCsvImportAction> createState() =>
      _AdminMenuCsvImportActionState();
}

class _AdminMenuCsvImportActionState
    extends ConsumerState<AdminMenuCsvImportAction> {
  bool _isImporting = false;

  Future<void> _importCsv(List<Venue> venues) async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: true,
        allowedExtensions: const ['csv'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('The selected file could not be read.');
      }
      final content = utf8.decode(bytes);
      final rows = const CsvDecoder(dynamicTyping: false).convert(content);
      if (rows.length < 2) {
        throw Exception('Add a header row and at least one menu item row.');
      }
      final header = rows.first
          .map((cell) => cell.toString().trim().toLowerCase())
          .toList(growable: false);
      final items = <Map<String, dynamic>>[];
      for (final row in rows.skip(1)) {
        final cells = row.map((cell) => cell.toString().trim()).toList();
        if (cells.every((cell) => cell.isEmpty)) continue;
        String cell(String key) {
          final index = header.indexOf(key);
          if (index < 0 || index >= cells.length) return '';
          return cells[index];
        }

        final name = cell('name');
        if (name.isEmpty) continue;
        items.add({
          'name': name,
          'description': cell('description'),
          'category': cell('category').isEmpty
              ? 'Uncategorized'
              : cell('category'),
          'tags': cell('tags')
              .split(RegExp(r'[,;]'))
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList(growable: false),
          'class': cell('class').isEmpty ? null : cell('class').toLowerCase(),
          'image_url': cell('image_url').isEmpty
              ? cell('imageurl')
              : cell('image_url'),
        });
      }
      if (items.isEmpty) {
        throw Exception('No valid menu rows were found in the CSV.');
      }

      if (!mounted) return;
      final selection = await showModalBottomSheet<_VenueSelectionResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _VenueSelectionSheet(venues: venues),
      );
      if (selection == null) return;

      await MenuRepository.instance.createAdminMenuGroups(
        items: items,
        venueIds: selection.venueIds,
        assignAll: selection.assignAll,
      );
      ref.invalidate(adminMenuCatalogProvider);
      ref.invalidate(adminMenuQueueProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length} menu item(s) imported.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV import failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final venuesAsync = ref.watch(allVenuesProvider);
    return venuesAsync.when(
      loading: () => PremiumButton(
        label: 'UPLOAD CSV',
        icon: LucideIcons.upload,
        onPressed: null,
        isOutlined: true,
        isSmall: true,
      ),
      error: (_, _) => PremiumButton(
        label: 'UPLOAD CSV',
        icon: LucideIcons.upload,
        onPressed: null,
        isOutlined: true,
        isSmall: true,
      ),
      data: (venues) => PremiumButton(
        label: 'UPLOAD CSV',
        icon: LucideIcons.upload,
        isOutlined: true,
        isSmall: true,
        isLoading: _isImporting,
        onPressed: _isImporting ? null : () => _importCsv(venues),
      ),
    );
  }
}

class _VenueSelectionSheet extends StatefulWidget {
  final List<Venue> venues;

  const _VenueSelectionSheet({required this.venues});

  @override
  State<_VenueSelectionSheet> createState() => _VenueSelectionSheetState();
}

class _VenueSelectionSheetState extends State<_VenueSelectionSheet> {
  bool _assignAll = false;
  final Set<String> _selectedVenueIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.space4,
        AppTheme.space4,
        AppTheme.space4,
        MediaQuery.of(context).viewInsets.bottom + AppTheme.space4,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assign Imported Items',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppTheme.space2),
            SwitchListTile(
              value: _assignAll,
              onChanged: (value) => setState(() => _assignAll = value),
              title: const Text('Assign to all venues'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppTheme.space2),
            SizedBox(
              height: 260,
              child: ListView.builder(
                itemCount: widget.venues.length,
                itemBuilder: (context, index) {
                  final venue = widget.venues[index];
                  final isSelected = _selectedVenueIds.contains(venue.id);
                  return CheckboxListTile(
                    value: _assignAll ? true : isSelected,
                    onChanged: _assignAll
                        ? null
                        : (value) {
                            setState(() {
                              if (value == true) {
                                _selectedVenueIds.add(venue.id);
                              } else {
                                _selectedVenueIds.remove(venue.id);
                              }
                            });
                          },
                    title: Text(venue.name),
                    subtitle: Text(
                      venue.address.isEmpty ? venue.slug : venue.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            SizedBox(
              width: double.infinity,
              child: PremiumButton(
                label: 'IMPORT ITEMS',
                icon: LucideIcons.check,
                onPressed: () {
                  Navigator.of(context).pop(
                    _VenueSelectionResult(
                      assignAll: _assignAll,
                      venueIds: _selectedVenueIds.toList(growable: false),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueSelectionResult {
  final bool assignAll;
  final List<String> venueIds;

  const _VenueSelectionResult({
    required this.assignAll,
    required this.venueIds,
  });
}

class _FieldCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FieldCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ClayCard(
      padding: const EdgeInsets.all(AppTheme.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          ...children,
        ],
      ),
    );
  }
}

class _TextFieldBlock extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _TextFieldBlock({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.space2),
          TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: cs.surfaceContainerLow,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassDropdown extends StatelessWidget {
  final MenuItemClass? value;
  final ValueChanged<MenuItemClass?> onChanged;

  const _ClassDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CLASS',
          style: tt.labelSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTheme.space2),
        DropdownButtonFormField<MenuItemClass?>(
          initialValue: value,
          items: [
            const DropdownMenuItem<MenuItemClass?>(
              value: null,
              child: Text('Auto'),
            ),
            ...MenuItemClass.values.map(
              (itemClass) => DropdownMenuItem<MenuItemClass?>(
                value: itemClass,
                child: Text(itemClass.label),
              ),
            ),
          ],
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: cs.surfaceContainerLow,
          ),
        ),
      ],
    );
  }
}
