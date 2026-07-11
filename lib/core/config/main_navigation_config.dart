import 'package:flutter/material.dart';

enum MainNavigationDestination {
  home,
  introfilm,
  divisionA,
  divisionB,
  program,
  predict,
  poules,
  history,
  profile,
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
}

class MainNavigationConfig {
  const MainNavigationConfig._();

  static const homeIndex = 0;
  static const introfilmIndex = 1;
  static const divisionAIndex = 2;
  static const divisionBIndex = 3;
  static const programIndex = 4;
  static const predictIndex = 5;
  static const poulesIndex = 6;
  static const historyIndex = 7;
  static const profileIndex = 8;

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
      destination: MainNavigationDestination.introfilm,
      label: 'Introfilm',
      shortLabel: 'Introfilm',
      icon: Icons.ondemand_video_outlined,
      selectedIcon: Icons.ondemand_video_rounded,
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
