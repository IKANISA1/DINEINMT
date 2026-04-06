import 'dart:io';
import 'dart:convert';

void main() {
  final file = File('build/web/main.dart.js.info.json');
  if (!file.existsSync()) {
    print('No dump info file found.');
    exit(1);
  }

  print('Parsing 100MB+ json file...');
  final data = jsonDecode(file.readAsStringSync());
  final Map<String, dynamic> programInfosMap = data['elements']?['library'];
  if (programInfosMap == null) {
    print('No library info found in dump.');
    exit(1);
  }

  final List<dynamic> programInfos = programInfosMap.values.toList();
  final Map<String, int> packageSizes = {};
  int totalSize = 0;

  for (final lib in programInfos) {
    final size = lib['size'] as int;
    final name = lib['name'] as String;
    
    totalSize += size;
    
    final String uri = lib['canonicalUri'] ?? name;
    
    // Group by package
    String pkgName = 'Unknown';
    if (uri.startsWith('package:')) {
      pkgName = uri.split('/')[0];
    } else if (uri.startsWith('dart:')) {
      pkgName = uri.split(':')[0] + ':' + uri.split(':')[1].split('/')[0];
    } else if (uri.startsWith('file://')) {
      pkgName = 'App Source Code';
    } else {
      pkgName = uri.split(':')[0];
    }

    packageSizes[pkgName] = (packageSizes[pkgName] ?? 0) + size;
  }

  var sortedPackages = packageSizes.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  print('--- Bundle Weight by Package ---');
  print('Total Dart logic size: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB');
  for (int i = 0; i < 15 && i < sortedPackages.length; i++) {
    final pkg = sortedPackages[i];
    final pct = (pkg.value / totalSize * 100).toStringAsFixed(1);
    final sizeMb = (pkg.value / 1024 / 1024).toStringAsFixed(2);
    print('${pkg.key}: $sizeMb MB ($pct%)');
  }
}
