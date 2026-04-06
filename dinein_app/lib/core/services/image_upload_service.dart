import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'dinein_api_service.dart';
import 'auth_repository.dart';

/// Centralized service for picking and uploading images to Supabase Storage
/// via the DineIn edge function.
class ImageUploadService {
  ImageUploadService._();
  static final instance = ImageUploadService._();

  static const int _maxFileSizeBytes = 8 * 1024 * 1024; // 8MB

  final _picker = ImagePicker();

  Map<String, dynamic> _venueSessionPayload() {
    final session = AuthRepository.instance.currentVenueSession;
    if (session == null || session.accessToken.isEmpty) return const {};
    return {
      'venue_session': {'access_token': session.accessToken},
    };
  }

  /// Pick an image from gallery and upload as venue cover image.
  /// Returns the public URL of the uploaded image, or null if cancelled.
  Future<String?> pickAndUploadVenueImage(String venueId) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 80,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > _maxFileSizeBytes) {
      throw ImageUploadException(
        'Image is too large (${(bytes.lengthInBytes / 1024 / 1024).toStringAsFixed(1)}MB). '
        'Maximum size is ${_maxFileSizeBytes ~/ (1024 * 1024)}MB.',
      );
    }

    final base64Data = _toDataUri(bytes, file.path);

    final result = await DineinApiService.invoke(
      'upload_venue_image',
      payload: {
        'venueId': venueId,
        'image_data': base64Data,
        ..._venueSessionPayload(),
      },
    );

    final data = result as Map<String, dynamic>?;
    return data?['image_url'] as String?;
  }

  /// Pick an image from gallery and upload as menu item image.
  /// Returns the public URL of the uploaded image, or null if cancelled.
  Future<String?> pickAndUploadMenuItemImage(
    String venueId,
    String itemId,
  ) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > _maxFileSizeBytes) {
      throw ImageUploadException(
        'Image is too large (${(bytes.lengthInBytes / 1024 / 1024).toStringAsFixed(1)}MB). '
        'Maximum size is ${_maxFileSizeBytes ~/ (1024 * 1024)}MB.',
      );
    }

    final base64Data = _toDataUri(bytes, file.path);

    final result = await DineinApiService.invoke(
      'upload_menu_item_image',
      payload: {
        'venueId': venueId,
        'itemId': itemId,
        'image_data': base64Data,
        ..._venueSessionPayload(),
      },
    );

    final data = result as Map<String, dynamic>?;
    return data?['image_url'] as String?;
  }

  /// Convert bytes to a data URI with the detected MIME type.
  String _toDataUri(Uint8List bytes, String path) {
    final mime = _mimeFromPath(path);
    final b64 = base64Encode(bytes);
    return 'data:$mime;base64,$b64';
  }

  /// Detect MIME type from file extension.
  String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

/// Exception thrown when image upload fails due to client-side validation.
class ImageUploadException implements Exception {
  final String message;
  const ImageUploadException(this.message);

  @override
  String toString() => message;
}
