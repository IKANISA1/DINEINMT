import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'supabase_config.dart';

class AdminVenueAssetUploadException implements Exception {
  final String message;

  const AdminVenueAssetUploadException(this.message);

  @override
  String toString() => message;
}

class AdminVenueAssetService {
  AdminVenueAssetService._();

  static final instance = AdminVenueAssetService._();

  static const _bucket = 'venues';
  static const _maxUploadBytes = 10 * 1024 * 1024;
  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const _menuExtensions = {'pdf', 'jpg', 'jpeg', 'png'};

  Future<String> uploadVenueProfileImage(PlatformFile file) async {
    final prepared = _prepareFile(
      file,
      allowedExtensions: _imageExtensions,
      fallbackExtension: 'png',
      label: 'image',
    );

    final storagePath =
        'images/venue_${DateTime.now().microsecondsSinceEpoch}.${prepared.extension}';
    await SupabaseConfig.client.storage
        .from(_bucket)
        .uploadBinary(storagePath, prepared.bytes);

    return SupabaseConfig.client.storage.from(_bucket).getPublicUrl(storagePath);
  }

  Future<void> uploadMenuDocument(PlatformFile file) async {
    final prepared = _prepareFile(
      file,
      allowedExtensions: _menuExtensions,
      fallbackExtension: 'pdf',
      label: 'menu document',
    );

    final storagePath =
        'menus/menu_${DateTime.now().microsecondsSinceEpoch}.${prepared.extension}';
    await SupabaseConfig.client.storage
        .from(_bucket)
        .uploadBinary(storagePath, prepared.bytes);
  }

  _PreparedUpload _prepareFile(
    PlatformFile file, {
    required Set<String> allowedExtensions,
    required String fallbackExtension,
    required String label,
  }) {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw AdminVenueAssetUploadException('Cannot read $label data.');
    }
    if (bytes.lengthInBytes > _maxUploadBytes) {
      throw AdminVenueAssetUploadException(
        '${_capitalize(label)} is too large. '
        'Maximum size is ${_maxUploadBytes ~/ (1024 * 1024)}MB.',
      );
    }

    final extension = (file.extension ?? fallbackExtension).toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      final allowed = allowedExtensions.toList(growable: false)..sort();
      throw AdminVenueAssetUploadException(
        'Unsupported $label format. Allowed: ${allowed.join(', ')}.',
      );
    }

    return _PreparedUpload(bytes: bytes, extension: extension);
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class _PreparedUpload {
  final Uint8List bytes;
  final String extension;

  const _PreparedUpload({required this.bytes, required this.extension});
}
