import 'package:flutter_test/flutter_test.dart';

import 'package:core_pkg/constants/enums.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:db_pkg/models/models.dart';

void main() {
  test('adds one to input values', () {
    final calculator = Calculator();
    expect(calculator.addOne(2), 3);
    expect(calculator.addOne(-7), -6);
    expect(calculator.addOne(0), 1);
  });
}
