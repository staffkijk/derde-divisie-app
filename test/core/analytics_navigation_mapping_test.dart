import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/core/config/main_navigation_config.dart';

void main() {
  test('main navigation maps to stable analytics screen names', () {
    expect(
      MainNavigationConfig.items.map((item) => item.analyticsScreenName),
      [
        'home',
        'division_a',
        'division_b',
        'program',
        'predictions',
        'pools',
        'history',
        'profile',
      ],
    );
  });

  test('main navigation analytics names remain unique', () {
    final names =
        MainNavigationConfig.items.map((item) => item.analyticsScreenName);

    expect(names.toSet(), hasLength(names.length));
  });
}
