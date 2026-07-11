import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';

import 'core/config/main_navigation_config.dart';
import 'core/widgets/derde_div_logo.dart';
import 'helpers/announcement_service.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/derde_divisie/division_overview_screen.dart';
import 'features/derde_divisie/historical_standings_screen.dart';
import 'features/derde_divisie/unified_program_screen.dart';
import 'features/media/intro_video_screen.dart';
import 'package:derde_divisie/features/profiel/profile_screen.dart';
import 'features/moderator/moderator_dashboard_screen.dart';
import 'package:derde_divisie/features/poules/poules_overzicht_screen.dart';
import 'package:derde_divisie/features/voorspellen/prediction_overview_screen.dart';
import 'package:derde_divisie/features/auth/login_screen.dart';
import 'loggboek/update_log_button.dart';

const mainNavigationScreenTypes = <Type>[
  DashboardScreen,
  IntroVideoScreen,
  DivisionOverviewScreen,
  DivisionOverviewScreen,
  UnifiedProgramScreen,
  PredictionOverviewScreen,
  PoulesOverzichtScreen,
  HistoricalStandingsScreen,
  ProfileScreen,
];

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const _cream = Color(0xFFF3F6F1);

  int _selectedIndex = 0;
  bool isModerator = false;
  bool _hasMelding = false;

  late final StreamSubscription<User?> _authSub;

  final List<MainNavigationItemConfig> _navItems = MainNavigationConfig.items;

  @override
  void initState() {
    super.initState();
    _checkModeratorStatus();
    _loadRemoteConfig();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      AnnouncementService.maybeShow(context, isLoggedIn: loggedIn);
    });

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user != null) {
        AnnouncementService.maybeShow(context, isLoggedIn: true);
        _checkModeratorStatus();
        _loadRemoteConfig();
      } else {
        setState(() {
          isModerator = false;
          if (_navItems[_selectedIndex].protected) {
            _selectedIndex = 0;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  Future<void> _checkModeratorStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => isModerator = false);
      return;
    }

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final mod = userDoc.data()?['ismoderator'] == true;
      if (mounted) setState(() => isModerator = mod);
    } catch (e) {
      debugPrint('Fout bij laden moderatorstatus: $e');
    }
  }

  Future<void> _loadRemoteConfig() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate();
      if (mounted) setState(() => _hasMelding = rc.getBool('hasMelding'));
    } catch (e) {
      debugPrint('Fout bij laden remote config: $e');
      if (mounted) setState(() => _hasMelding = false);
    }
  }

  List<Widget> _screens() => [
        DashboardScreen(
          onOpenDivisionA: () =>
              _selectIndex(MainNavigationConfig.divisionAIndex),
          onOpenDivisionB: () =>
              _selectIndex(MainNavigationConfig.divisionBIndex),
          onOpenProgram: () => _selectIndex(MainNavigationConfig.programIndex),
          onOpenPredict: () => _selectIndex(MainNavigationConfig.predictIndex),
          onOpenPoules: () => _selectIndex(MainNavigationConfig.poulesIndex),
          onOpenProfile: () => _selectIndex(MainNavigationConfig.profileIndex),
          onOpenHistoricalStandings: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const HistoricalStandingsScreen(),
              ),
            );
          },
        ),
        const IntroVideoScreen(),
        const DivisionOverviewScreen(division: 'Derde Divisie A'),
        const DivisionOverviewScreen(division: 'Derde Divisie B'),
        const UnifiedProgramScreen(),
        const PredictionOverviewScreen(),
        const PoulesOverzichtScreen(),
        const HistoricalStandingsScreen(),
        const ProfileScreen(),
      ];

  Future<bool> _ensureLoggedIn() async {
    if (FirebaseAuth.instance.currentUser != null) return true;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    return result == true || FirebaseAuth.instance.currentUser != null;
  }

  Future<void> _selectIndex(int index) async {
    final item = _navItems[index];
    if (item.protected && !await _ensureLoggedIn()) return;
    if (!mounted) return;
    setState(() => _selectedIndex = index);
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Je bent uitgelogd.')),
    );
  }

  void _openModerator() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ModeratorDashboardScreen()),
    );
  }

  Future<void> _showMobileMenu() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final index in [
                  MainNavigationConfig.programIndex,
                  MainNavigationConfig.predictIndex,
                  MainNavigationConfig.poulesIndex,
                  MainNavigationConfig.historyIndex,
                  MainNavigationConfig.profileIndex,
                ])
                  ListTile(
                    leading: Icon(
                      _selectedIndex == index
                          ? _navItems[index].selectedIcon
                          : _navItems[index].icon,
                    ),
                    title: Text(_navItems[index].label),
                    trailing: _navItems[index].protected &&
                            FirebaseAuth.instance.currentUser == null
                        ? const Icon(Icons.lock_outline, size: 17)
                        : null,
                    selected: _selectedIndex == index,
                    onTap: () => Navigator.of(context).pop(index),
                  ),
                if (isModerator)
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Moderator'),
                    onTap: () => Navigator.of(context).pop(99),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    if (selected == 99) {
      _openModerator();
    } else {
      await _selectIndex(selected);
    }
  }

  void _showAnnouncement(bool loggedIn) {
    AnnouncementService.showAgain(context, isLoggedIn: loggedIn);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
        final loggedIn = user != null;
        final screens = _screens();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 980;
            final isTablet = constraints.maxWidth >= 720 && !isDesktop;

            if (isDesktop) {
              return Scaffold(
                backgroundColor: _cream,
                body: Row(
                  children: [
                    _DesktopNavigation(
                      items: _navItems,
                      selectedIndex: _selectedIndex,
                      loggedIn: loggedIn,
                      isModerator: isModerator,
                      onSelect: _selectIndex,
                      onLogin: _ensureLoggedIn,
                      onLogout: _signOut,
                      onModerator: _openModerator,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _DesktopHeader(
                            title: _navItems[_selectedIndex].label,
                            loggedIn: loggedIn,
                            hasMelding: _hasMelding,
                            isModerator: isModerator,
                            onLogin: _ensureLoggedIn,
                            onLogout: _signOut,
                            onShowAnnouncement: () =>
                                _showAnnouncement(loggedIn),
                            onModerator: _openModerator,
                          ),
                          Expanded(
                            child: Container(
                              color: _cream,
                              child: screens[_selectedIndex],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              backgroundColor: _cream,
              appBar: AppBar(
                titleSpacing: 16,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const DerdeDivLogo.compact(width: 30, height: 30),
                    const SizedBox(width: 10),
                    Text(
                      isTablet
                          ? _navItems[_selectedIndex].label
                          : _navItems[_selectedIndex].shortLabel,
                    ),
                  ],
                ),
                actions: [
                  UpdateLogButton(isAdmin: isModerator),
                  if (_hasMelding)
                    IconButton(
                      icon: const Icon(Icons.notifications_active_outlined),
                      tooltip: 'Melding opnieuw tonen',
                      onPressed: () => _showAnnouncement(loggedIn),
                    ),
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    tooltip: 'Help',
                    onPressed: () => Navigator.pushNamed(context, '/help'),
                  ),
                  if (isModerator)
                    IconButton(
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      tooltip: 'Moderatorpaneel',
                      onPressed: _openModerator,
                    ),
                  if (!loggedIn)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton(
                        onPressed: _ensureLoggedIn,
                        child: const Text(
                          'Login',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: 'Uitloggen',
                      onPressed: _signOut,
                    ),
                ],
              ),
              body: screens[_selectedIndex],
              bottomNavigationBar: NavigationBar(
                selectedIndex:
                    _selectedIndex <= MainNavigationConfig.divisionBIndex
                        ? _selectedIndex
                        : 4,
                onDestinationSelected: (index) {
                  if (index <= MainNavigationConfig.divisionBIndex) {
                    _selectIndex(index);
                  } else {
                    _showMobileMenu();
                  }
                },
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  for (final item in _navItems.take(4))
                    NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: item.shortLabel,
                    ),
                  const NavigationDestination(
                    icon: Icon(Icons.more_horiz),
                    selectedIcon: Icon(Icons.more),
                    label: 'Meer',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  static const _green = Color(0xFF2F8F3B);
  static const _darkGreen = Color(0xFF153B2A);

  final List<MainNavigationItemConfig> items;
  final int selectedIndex;
  final bool loggedIn;
  final bool isModerator;
  final ValueChanged<int> onSelect;
  final Future<bool> Function() onLogin;
  final VoidCallback onLogout;
  final VoidCallback onModerator;

  const _DesktopNavigation({
    required this.items,
    required this.selectedIndex,
    required this.loggedIn,
    required this.isModerator,
    required this.onSelect,
    required this.onLogin,
    required this.onLogout,
    required this.onModerator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 292,
      color: _darkGreen,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 64,
                alignment: Alignment.centerLeft,
                child: const DerdeDivLogo.full(width: 210, height: 56),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .10),
                  ),
                ),
                child: Text(
                  loggedIn
                      ? 'Welkom terug. Je voorspellingen, poules en profiel zijn direct beschikbaar.'
                      : 'Volg standen en programma zonder account. Log in om te voorspellen of een poule te beheren.',
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              ...List.generate(items.length, (index) {
                final item = items[index];
                final selected = index == selectedIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DesktopNavButton(
                    item: item,
                    selected: selected,
                    enabled: !item.protected || loggedIn,
                    onTap: () => onSelect(index),
                  ),
                );
              }),
              if (isModerator) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onModerator,
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Moderator'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: .26),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (loggedIn)
                OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Uitloggen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: .26),
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: onLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('Inloggen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _green,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopNavButton extends StatelessWidget {
  final MainNavigationItemConfig item;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _DesktopNavButton({
    required this.item,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? const Color(0xFF153B2A)
        : enabled
            ? Colors.white
            : Colors.white54;

    final iconColor = selected
        ? const Color(0xFF153B2A)
        : enabled
            ? Colors.white70
            : Colors.white38;

    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                color: iconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (item.protected && !enabled)
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: selected ? const Color(0xFF153B2A) : Colors.white54,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  final String title;
  final bool loggedIn;
  final bool hasMelding;
  final bool isModerator;
  final Future<bool> Function() onLogin;
  final VoidCallback onLogout;
  final VoidCallback onShowAnnouncement;
  final VoidCallback onModerator;

  const _DesktopHeader({
    required this.title,
    required this.loggedIn,
    required this.hasMelding,
    required this.isModerator,
    required this.onLogin,
    required this.onLogout,
    required this.onShowAnnouncement,
    required this.onModerator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE3EADF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF153B2A),
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          UpdateLogButton(
            isAdmin: isModerator,
            iconColor: const Color(0xFF153B2A),
          ),
          if (hasMelding)
            IconButton(
              icon: const Icon(Icons.notifications_active_outlined),
              tooltip: 'Melding opnieuw tonen',
              onPressed: onShowAnnouncement,
            ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () => Navigator.pushNamed(context, '/help'),
          ),
          if (isModerator)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Moderatorpaneel',
              onPressed: onModerator,
            ),
          const SizedBox(width: 8),
          if (loggedIn)
            OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Uitloggen'),
            )
          else
            ElevatedButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Inloggen'),
            ),
        ],
      ),
    );
  }
}
