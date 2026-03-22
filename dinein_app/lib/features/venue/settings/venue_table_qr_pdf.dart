import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_download_links.dart';
import '../../../core/models/models.dart';

class VenueTableQrEntry {
  final int tableNumber;
  final Uri redirectUri;
  final Uri deepLinkUri;

  const VenueTableQrEntry({
    required this.tableNumber,
    required this.redirectUri,
    required this.deepLinkUri,
  });

  String get tableNumberText => tableNumber.toString();
  String get paddedTableNumber => tableNumber.toString().padLeft(2, '0');
  String get printedLabel => 'Table $tableNumberText';
}

List<VenueTableQrEntry> buildVenueTableQrEntries({
  required Venue venue,
  required int tableCount,
}) {
  return List.generate(tableCount, (index) {
    final tableNumber = index + 1;
    final tableNumberText = tableNumber.toString();
    return VenueTableQrEntry(
      tableNumber: tableNumber,
      redirectUri: buildVenueTableDownloadRedirectUri(
        slug: venue.slug,
        tableNumber: tableNumberText,
        venueName: venue.name,
      ),
      deepLinkUri: buildVenueTableDeepLinkUri(
        slug: venue.slug,
        tableNumber: tableNumberText,
      ),
    );
  });
}

String buildVenueTableQrFilename(Venue venue, {DateTime? now}) {
  final timestamp = DateFormat('yyyyMMdd').format(now ?? DateTime.now());
  return 'venue_table_qr_${venue.slug}_$timestamp.pdf';
}

Future<Uint8List> buildVenueTableQrPdfBytes({
  required Venue venue,
  required int tableCount,
  Uint8List? brandImageBytes,
}) async {
  final entries = buildVenueTableQrEntries(
    venue: venue,
    tableCount: tableCount,
  );
  final doc = pw.Document(
    title: '${venue.name} table QR pack',
    author: 'DineIn Malta',
    creator: 'DineIn Malta venue tools',
    subject: 'Printable QR code pack for venue tables',
  );
  final brandImage = brandImageBytes == null
      ? null
      : pw.MemoryImage(brandImageBytes);

  for (final pageEntries in _chunk(entries, 4)) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Column(
          children: [
            _buildPageRow(pageEntries.take(2).toList(), venue, brandImage),
            pw.SizedBox(height: 16),
            _buildPageRow(
              pageEntries.skip(2).take(2).toList(),
              venue,
              brandImage,
            ),
          ],
        ),
      ),
    );
  }

  return doc.save();
}

pw.Widget _buildPageRow(
  List<VenueTableQrEntry> entries,
  Venue venue,
  pw.MemoryImage? brandImage,
) {
  return pw.Expanded(
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: List.generate(2, (index) {
        final entry = index < entries.length ? entries[index] : null;
        return pw.Expanded(
          child: pw.Padding(
            padding: pw.EdgeInsets.only(
              left: index == 0 ? 0 : 8,
              right: index == 0 ? 8 : 0,
            ),
            child: entry == null
                ? pw.SizedBox.expand()
                : _buildQrCard(entry, venue, brandImage),
          ),
        );
      }),
    ),
  );
}

pw.Widget _buildQrCard(
  VenueTableQrEntry entry,
  Venue venue,
  pw.MemoryImage? brandImage,
) {
  final gold = PdfColor.fromInt(0xFFE1C28E);
  final brandGold = PdfColor.fromInt(0xFF8B7A3D);
  final shell = PdfColor.fromInt(0xFF141414);
  final shellSoft = PdfColor.fromInt(0xFF1A1C1E);
  final mint = PdfColor.fromInt(0xFFA1D494);

  return pw.Container(
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      color: shell,
      borderRadius: pw.BorderRadius.circular(28),
      border: pw.Border.all(color: gold, width: 1.25),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 36,
              height: 36,
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: brandImage == null
                  ? pw.Center(
                      child: pw.Text(
                        'DI',
                        style: pw.TextStyle(
                          color: brandGold,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    )
                  : pw.ClipRRect(
                      horizontalRadius: 12,
                      verticalRadius: 12,
                      child: pw.Image(brandImage, fit: pw.BoxFit.cover),
                    ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DINEIN MALTA',
                    style: pw.TextStyle(
                      color: gold,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    venue.name,
                    maxLines: 2,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: pw.BoxDecoration(
            color: shellSoft,
            borderRadius: pw.BorderRadius.circular(18),
            border: pw.Border.all(color: gold, width: 0.8),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                'TABLE',
                style: pw.TextStyle(
                  color: gold,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2.1,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                entry.paddedTableNumber,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(22),
            ),
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: entry.redirectUri.toString(),
              color: PdfColors.black,
              width: 150,
              height: 150,
            ),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Scan to open ${entry.printedLabel} with DINEIN.',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Android opens Google Play. Other devices open the venue page.',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: mint,
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF101214),
            borderRadius: pw.BorderRadius.circular(16),
          ),
          child: pw.Text(
            'Smart redirect · dineinmalta.com/download',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: gold,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

List<List<T>> _chunk<T>(List<T> items, int size) {
  final pages = <List<T>>[];
  for (var i = 0; i < items.length; i += size) {
    pages.add(
      items.sublist(i, i + size > items.length ? items.length : i + size),
    );
  }
  return pages;
}
