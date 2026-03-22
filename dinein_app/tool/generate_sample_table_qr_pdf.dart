import 'dart:io';

import 'package:dinein_app/core/models/models.dart';
import 'package:dinein_app/features/venue/settings/venue_table_qr_pdf.dart';

Future<void> main() async {
  final venue = Venue(
    id: 'sample-venue',
    name: 'DINEIN Malta Demo Venue',
    slug: 'demo-venue',
    category: 'Restaurants',
    description: 'Sample venue for QR PDF QA.',
    address: '78 Villegaignon St, Mdina, Malta',
  );

  final brandLogoBytes = await File(
    'assets/branding/dinein_logo.png',
  ).readAsBytes();
  final pdfBytes = await buildVenueTableQrPdfBytes(
    venue: venue,
    tableCount: 6,
    brandImageBytes: brandLogoBytes,
  );

  final outputDir = Directory('tmp/pdfs')..createSync(recursive: true);
  final outputFile = File('${outputDir.path}/venue_table_qr_sample.pdf');
  await outputFile.writeAsBytes(pdfBytes, flush: true);

  stdout.writeln(outputFile.path);
}
