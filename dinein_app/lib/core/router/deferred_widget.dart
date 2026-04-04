import 'package:flutter/material.dart';
import 'package:ui/widgets/shared_widgets.dart';

typedef LibraryLoader = Future<void> Function();
typedef DeferredBuilder = Widget Function(BuildContext context);

class DeferredWidget extends StatefulWidget {
  final LibraryLoader libraryLoader;
  final DeferredBuilder createWidget;

  const DeferredWidget({
    super.key,
    required this.libraryLoader,
    required this.createWidget,
  });

  @override
  State<DeferredWidget> createState() => _DeferredWidgetState();
}

class _DeferredWidgetState extends State<DeferredWidget> {
  bool _loaded = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    try {
      await widget.libraryLoader();
      if (mounted) {
        setState(() {
          _loaded = true;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) {
      return widget.createWidget(context);
    }
    if (_error) {
      return Scaffold(
        body: ErrorState(
          message: 'Failed to load module. Please check your connection.',
          onRetry: _loadLibrary,
        ),
      );
    }
    return const Scaffold(
      body: Center(
        child: SkeletonLoader(width: double.infinity, height: 200),
      ),
    );
  }
}
