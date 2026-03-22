import 'dart:io';

import 'package:dinein_app/core/config/country_config.dart';
import 'package:dinein_app/core/constants/enums.dart';
import 'package:dinein_app/core/models/models.dart';
import 'package:dinein_app/features/venue/settings/venue_table_qr_pdf.dart';

Future<void> main(List<String> args) async {
  final country = _countryFromArgs(args);
  final config = country == 'rw' ? CountryConfig.rw : CountryConfig.mt;
  final venue = Venue(
    id: 'sample-venue',
    name: config.country == Country.rw
        ? 'DINEIN Rwanda Demo Venue'
        : 'DINEIN Malta Demo Venue',
    slug: 'demo-venue',
    category: 'Restaurants',
    description: 'Sample venue for QR PDF QA.',
    address: config.country == Country.rw
        ? 'KG 9 Ave, Kigali, Rwanda'
        : '78 Villegaignon St, Mdina, Malta',
    country: config.country,
  );

  final brandLogoBytes = await File(
    'assets/branding/dinein_logo.png',
  ).readAsBytes();
  final pdfBytes = await buildVenueTableQrPdfBytes(
    venue: venue,
    tableCount: 6,
    brandImageBytes: brandLogoBytes,
    config: config,
  );

  final outputDir = Directory('tmp/pdfs')..createSync(recursive: true);
  final outputFile = File('${outputDir.path}/venue_table_qr_sample.pdf');
  await outputFile.writeAsBytes(pdfBytes, flush: true);

  stdout.writeln(outputFile.path);
}

String _countryFromArgs(List<String> args) {
  final countryIndex = args.indexOf('--country');
  if (countryIndex == -1 || countryIndex + 1 >= args.length) return 'mt';
  final country = args[countryIndex + 1].trim().toLowerCase();
  return country == 'rw' ? 'rw' : 'mt';
}
