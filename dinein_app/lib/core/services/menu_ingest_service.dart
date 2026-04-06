import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'package:db_pkg/models/models.dart';
import 'auth_repository.dart';
import 'dinein_api_service.dart';

/// Result of a menu document ingestion operation.
class MenuIngestResult {
  final int createdCount;
  final int skippedCount;
  final String message;
  final List<MenuItem> items;

  const MenuIngestResult({
    required this.createdCount,
    required this.skippedCount,
    required this.message,
    required this.items,
  });

  factory MenuIngestResult.fromJson(Map<String, dynamic> json) {
    return MenuIngestResult(
      createdCount: (json['created_count'] as num?)?.toInt() ?? 0,
      skippedCount: (json['skipped_count'] as num?)?.toInt() ?? 0,
      message: json['message'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Exception thrown for menu ingestion errors.
class MenuIngestException implements Exception {
  final String message;
  const MenuIngestException(this.message);

  @override
  String toString() => message;
}

/// Service for picking menu documents and uploading them for AI extraction.
class MenuIngestService {
  MenuIngestService._();
  static final instance = MenuIngestService._();

  /// Max file size: 10MB
  static const int _maxFileSizeBytes = 10 * 1024 * 1024;

  /// Supported file extensions
  static const _allowedExtensions = [
    'jpg', 'jpeg', 'png', 'webp', 'gif', // images
    'pdf', // PDFs
    'xlsx', 'xls', 'csv', // spreadsheets
    'docx', 'doc', // word docs
    'txt', // plain text
  ];

  /// MIME type mapping for common extensions
  static const _mimeTypes = <String, String>{
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'pdf': 'application/pdf',
    'xlsx':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'xls': 'application/vnd.ms-excel',
    'csv': 'text/csv',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'doc': 'application/msword',
    'txt': 'text/plain',
  };

  Map<String, dynamic> _venueSessionPayload() {
    final session = AuthRepository.instance.currentVenueSession;
    if (session == null || session.accessToken.isEmpty) return const {};
    return {
      'venue_session': {'access_token': session.accessToken},
    };
  }

  /// Pick a file from the device and ingest it as menu data.
  ///
  /// Opens the native file picker, reads the selected file,
  /// sends it to the edge function for Gemini AI extraction,
  /// and returns the result with created menu items.
  ///
  /// Returns null if the user cancels the file picker.
  Future<MenuIngestResult?> pickAndIngestMenuDocument(
    String venueId, {
    String? country,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    final fileName = file.name;

    if (bytes == null || bytes.isEmpty) {
      throw const MenuIngestException(
        'Could not read the selected file. Please try again.',
      );
    }

    if (bytes.lengthInBytes > _maxFileSizeBytes) {
      throw MenuIngestException(
        'File is too large (${(bytes.lengthInBytes / 1024 / 1024).toStringAsFixed(1)}MB). '
        'Maximum size is ${_maxFileSizeBytes ~/ (1024 * 1024)}MB.',
      );
    }

    // Detect MIME type from extension
    final ext = fileName.split('.').last.toLowerCase();
    final mimeType = _mimeTypes[ext] ?? 'application/octet-stream';

    // Convert to base64
    final base64Data = base64Encode(bytes);

    debugPrint(
      '[MenuIngestService] Uploading $fileName ($ext, ${(bytes.lengthInBytes / 1024).toStringAsFixed(0)}KB) for venue $venueId',
    );

    final response = await DineinApiService.invoke(
      'ingest_menu_document',
      payload: {
        'venueId': venueId,
        'file_data': base64Data,
        'file_name': fileName,
        'mime_type': mimeType,
        'country': ?country,
        ..._venueSessionPayload(),
      },
    );

    final data = response as Map<String, dynamic>? ?? {};
    return MenuIngestResult.fromJson(data);
  }
}
