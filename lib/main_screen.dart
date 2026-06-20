import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';

import 'helpers/announcement_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/stand_derde_divisie.dart';
import 'screens/profile_screen.dart';
import 'moderator/moderator_menu_screen.dart';
import 'poules/screens/poules_overzicht_screen.dart';
import 'screens/prediction_overview_screen.dart';
import 'Inloggen/login_screen.dart';
import 'loggboek/update_log_button.dart';

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

  final List<_NavItem> _navItems = const [
    _NavItem(
      label: 'Home',
      shortLabel: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      protected: false,
    ),
    _NavItem(
      label: 'Derde Divisie',
      shortLabel: 'Stand',
      icon: Icons.leaderboard_outlined,
      selectedIcon: Icons.leaderboard,
      protected: false,
    ),
    _NavItem(
      label: 'Voorspellen',
      shortLabel: 'Voorspellen',
      icon: Icons.edit_calendar_outlined,
      selectedIcon: Icons.edit_calendar,
      protected: true,
    ),
    _NavItem(
      label: 'Poules',
      shortLabel: 'Poules',
      icon: Icons.groups_2_outlined,
      selectedIcon: Icons.groups_2,
      protected: true,
    ),
    _NavItem(
      label: 'Profiel',
      shortLabel: 'Profiel',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      protected: true,
    ),
  ];

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
      final mod = userDoc.data()?['isModerator'] == true;
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
          onOpenStand: () => _selectIndex(1),
          onOpenPredict: () => _selectIndex(2),
          onOpenPoules: () => _selectIndex(3),
        ),
        const StandDerdeDivisieScreen(),
        const PredictionOverviewScreen(),
        const PoulesOverzichtScreen(),
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
      MaterialPageRoute(builder: (_) => const ModeratorMenuScreen()),
    );
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
                            onShowAnnouncement: () => _showAnnouncement(loggedIn),
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
                    Image.asset(
                      'assets/derde_divisie_logo_icon.png',
                      width: 30,
                      height: 30,
                    ),
                    const SizedBox(width: 10),
                    Text(isTablet ? _navItems[_selectedIndex].label : 'Derde Divisie'),
                  ],
                ),
                actions: [
                  UpdateLogButton(
            isAdmin: isModerator,
            iconColor: const Color(0xFF153B2A),
          ),
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
                selectedIndex: _selectedIndex,
                onDestinationSelected: _selectIndex,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: _navItems
                    .map(
                      (item) => NavigationDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: item.shortLabel,
                      ),
                    )
                    .toList(),
              ),
            );
          },
        );
      },
    );
  }
}

class _NavItem {
  final String label;
  final String shortLabel;
  final IconData icon;
  final IconData selectedIcon;
  final bool protected;

  const _NavItem({
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.selectedIcon,
    required this.protected,
  });
}

class _DesktopNavigation extends StatelessWidget {
  static const _green = Color(0xFF2F8F3B);
  static const _darkGreen = Color(0xFF153B2A);

  final List<_NavItem> items;
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Image.asset('assets/derde_divisie_logo_icon.png'),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DerdeDiv.nl',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Derde Divisie centraal',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: .10)),
                ),
                child: const Text(
                  'Volg standen, programma en cijfers zonder account. Log in wanneer je wilt voorspellen of een poule wilt beheren.',
                  style: TextStyle(color: Colors.white70, height: 1.35),
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
                    onTap: () => onSelect(index),
                  ),
                );
              }),
              const Spacer(),
              if (isModerator)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: onModerator,
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Moderator'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: .26)),
                    ),
                  ),
                ),
              if (loggedIn)
                OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Uitloggen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: .26)),
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
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _DesktopNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                color: selected ? const Color(0xFF153B2A) : Colors.white70,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? const Color(0xFF153B2A) : Colors.white,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (item.protected)
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
          UpdateLogButton(isAdmin: isModerator),
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
