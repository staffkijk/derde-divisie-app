import 'package:flutter/material.dart';

enum MainNavigationDestination {
  home,
  divisionA,
  divisionB,
  program,
  predict,
  poules,
  history,
  profile,
}

extension MainNavigationDestinationAnalytics on MainNavigationDestination {
  String get analyticsName {
    switch (this) {
      case MainNavigationDestination.home:
        return 'home';
      case MainNavigationDestination.divisionA:
        return 'division_a';
      case MainNavigationDestination.divisionB:
        return 'division_b';
      case MainNavigationDestination.program:
        return 'program';
      case MainNavigationDestination.predict:
        return 'predictions';
      case MainNavigationDestination.poules:
        return 'pools';
      case MainNavigationDestination.history:
        return 'history';
      case MainNavigationDestination.profile:
        return 'profile';
    }
  }
}

class MainNavigationItemConfig {
  final MainNavigationDestination destination;
  final String label;
  final String shortLabel;
  final IconData icon;
  final IconData selectedIcon;
  final bool protected;

  const MainNavigationItemConfig({
    required this.destination,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.selectedIcon,
    required this.protected,
  });

  String get analyticsScreenName => destination.analyticsName;
}

class MainNavigationConfig {
  const MainNavigationConfig._();

  static const homeIndex = 0;
  static const divisionAIndex = 1;
  static const divisionBIndex = 2;
  static const programIndex = 3;
  static const predictIndex = 4;
  static const poulesIndex = 5;
  static const historyIndex = 6;
  static const profileIndex = 7;

  static const items = [
    MainNavigationItemConfig(
      destination: MainNavigationDestination.home,
      label: 'Home',
      shortLabel: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      protected: false,
    ),
    MainNavigationItemConfig(
      destination: MainNavigationDestination.divisionA,
      label: 'Derde Divisie A',
      shortLabel: 'A',
      icon: Icons.leaderboard_outlined,
      selectedIcon: Icons.leaderboard,
      protected: false,
    ),
    MainNavigationItemConfig(
      destination: MainNavigationDestination.divisionB,
      label: 'Derde Divisie B',
      shortLabel: 'B',
      icon: Icons.leaderboard_outlined,
      selectedIcon: Icons.leaderboard,
      protected: false,
    ),
    MainNavigationItemConfig(
      destination: MainNavigationDestination.program,
      label: 'Programma',
      shortLabel: 'Programma',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      protected: false,
    ),
    MainNavigationItemConfig(
      destination: MainNavigationDestination.predict,
      label: 'Voorspellen',
      shortLabel: 'Voorspellen',
      icon: Icons.edit_calendar_outlined,
      selectedIcon: Icons.edit_calendar,
      protected: true,
    ),
    MainNavigationItemConfig(
      destination: MainNavigationDestination.poules,
      label: 'Poules',
      shortLabel: 'Poules',
      icon: Icons.groups_2_outlined,
      selectedIcon: Icons.groups_2,
      protected: true,
    ),
    MainNavigationItemConfig(
      destination: MainNavigationDestination.history,
      label: 'Geschiedenis',
      shortLabel: 'Historie',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      protected: false,
    ),
    MainNavigationItemConfig(
      destination: MainNavigationDestination.profile,
      label: 'Profiel',
      shortLabel: 'Profiel',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      protected: true,
    ),
  ];
}
