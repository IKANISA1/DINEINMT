import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/providers.dart';
import '../../core/services/bell_repository.dart';
import 'shared_widgets.dart';

class WaveBottomSheet extends ConsumerStatefulWidget {
  final String venueId;

  const WaveBottomSheet({super.key, required this.venueId});

  @override
  ConsumerState<WaveBottomSheet> createState() => _WaveBottomSheetState();

  static Future<void> show(BuildContext context, String venueId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => WaveBottomSheet(venueId: venueId),
    );
  }
}

class _WaveBottomSheetState extends ConsumerState<WaveBottomSheet> {
  final _tableController = TextEditingController();
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartProvider);
    _tableController.text = cart.tableNumber ?? '';
  }

  @override
  void dispose() {
    _tableController.dispose();
    super.dispose();
  }

  Future<void> _sendWave() async {
    final tableStr = _tableController.text.trim();
    if (tableStr.isEmpty) {
      setState(() => _error = 'Please enter your table number.');
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      final user = ref.read(currentUserProvider);
      await BellRepository.instance.sendWave(
        venueId: widget.venueId,
        tableNumber: tableStr,
        userId: user?.id,
      );

      // Save table number in cart if it wasn't already there
      ref.read(cartProvider.notifier).setTableNumber(tableStr);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Staff has been notified. They will be with you shortly.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          final msg = e.toString().replaceFirst('Exception: ', '');
          _error = msg.isNotEmpty ? msg : 'Could not send request. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.space8,
        right: AppTheme.space8,
        top: AppTheme.space8,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.space8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(LucideIcons.hand, color: cs.primary),
              ),
              const SizedBox(width: AppTheme.space4),
              Text('Call Staff', style: tt.headlineSmall),
            ],
          ),
          const SizedBox(height: AppTheme.space6),
          Text(
            'Need assistance? Enter your table number below and we will notify the staff immediately.',
            style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.space6),
          TextField(
            controller: _tableController,
            keyboardType: TextInputType.number,
            style: tt.headlineMedium,
            decoration: InputDecoration(
              hintText: 'Table Number',
              filled: true,
              fillColor: cs.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppTheme.space4),
            Text(
              _error!,
              style: tt.bodyMedium?.copyWith(color: cs.error),
            ),
          ],
          const SizedBox(height: AppTheme.space8),
          PremiumButton(
            label: 'SEND REQUEST',
            icon: LucideIcons.send,
            isLoading: _isSending,
            onPressed: _sendWave,
          ),
        ],
      ),
    );
  }
}
