import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/core/config/main_navigation_config.dart';

void main() {
  group('MainNavigationConfig', () {
    test('toont Introfilm niet als menu-item', () {
      expect(
        MainNavigationConfig.items.map((item) => item.label),
        isNot(contains('Introfilm')),
      );
    });

    test('houdt menu-indexen gekoppeld aan de juiste schermen', () {
      expect(
        MainNavigationConfig.items[MainNavigationConfig.homeIndex].destination,
        MainNavigationDestination.home,
      );
      expect(
        MainNavigationConfig
            .items[MainNavigationConfig.divisionAIndex].destination,
        MainNavigationDestination.divisionA,
      );
      expect(
        MainNavigationConfig
            .items[MainNavigationConfig.divisionBIndex].destination,
        MainNavigationDestination.divisionB,
      );
      expect(
        MainNavigationConfig
            .items[MainNavigationConfig.programIndex].destination,
        MainNavigationDestination.program,
      );
      expect(
        MainNavigationConfig
            .items[MainNavigationConfig.predictIndex].destination,
        MainNavigationDestination.predict,
      );
      expect(
        MainNavigationConfig
            .items[MainNavigationConfig.profileIndex].destination,
        MainNavigationDestination.profile,
      );
    });
  });
}
