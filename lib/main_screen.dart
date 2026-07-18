import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Type;
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
import 'features/notifications/notification_center_screen.dart';
import 'features/about/juridisch_scherm.dart';
import 'package:derde_divisie/features/profiel/profile_screen.dart';
import 'features/moderator/moderator_dashboard_screen.dart';
import 'package:derde_divisie/features/poules/poules_overzicht_screen.dart';
import 'package:derde_divisie/features/voorspellen/prediction_overview_screen.dart';
import 'package:derde_divisie/features/auth/login_screen.dart';
import 'data/services/activity_log_service.dart';
import 'data/services/analytics_service.dart';
import 'data/services/prediction_reminder_service.dart';
import 'data/models/notification_collection_utils.dart';
import 'loggboek/update_log_button.dart';

const mainNavigationScreenTypes = <Type>[
  DashboardScreen,
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
  bool _showAnalyticsConsentBanner = false;
  int? _lastTrackedIndex;

  late final StreamSubscription<User?> _authSub;
  final _reminderService = PredictionReminderService();

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
      _trackScreenView(_selectedIndex);
      _maybeShowAnalyticsConsent();
    });

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user != null) {
        AnnouncementService.maybeShow(context, isLoggedIn: true);
        _checkModeratorStatus();
        _loadRemoteConfig();
        _syncPredictionReminders();
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

  void _openIntrofilmFromHome() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const IntroVideoScreen()),
    );
  }

  List<Widget> _screens() => [
        DashboardScreen(
          onOpenIntrofilm: _openIntrofilmFromHome,
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
    await ActivityLogService().log(
      eventType: ActivityEventType.navigationClick,
      metadata: {
        'destination': item.label,
        'screenName': item.label,
      },
    );
    setState(() => _selectedIndex = index);
    _trackScreenView(index);
  }

  void _trackScreenView(int index) {
    if (_lastTrackedIndex == index) return;
    _lastTrackedIndex = index;
    final item = _navItems[index];
    ActivityLogService().log(
      eventType: ActivityEventType.screenView,
      metadata: {
        'screenName': item.label,
        'destination': item.label,
      },
    );
    AnalyticsService.instance.trackScreenView(
      item.analyticsScreenName,
      loggedIn: FirebaseAuth.instance.currentUser != null,
    );
  }

  void _trackAnalyticsScreenOnly(int index) {
    final item = _navItems[index];
    AnalyticsService.instance.trackScreenView(
      item.analyticsScreenName,
      loggedIn: FirebaseAuth.instance.currentUser != null,
    );
  }

  Future<void> _maybeShowAnalyticsConsent() async {
    final service = AnalyticsService.instance;
    await service.initialize();
    if (!mounted) return;
    setState(() => _showAnalyticsConsentBanner = service.shouldAskConsent);
  }

  Future<void> _setAnalyticsConsent(bool accepted) async {
    final service = AnalyticsService.instance;
    await service.setConsent(accepted);
    if (!mounted) return;
    setState(() => _showAnalyticsConsentBanner = false);
    if (accepted) {
      service.resetScreenTracking();
      _trackAnalyticsScreenOnly(_selectedIndex);
    }
  }

  void _openPrivacyInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const JuridischScherm(scrollTo: 'privacy'),
      ),
    );
  }

  Future<void> _selectMobileDestination(int index) async {
    switch (index) {
      case 0:
        await _selectIndex(MainNavigationConfig.homeIndex);
        return;
      case 1:
        if (!mounted) return;
        var nextIndex = _selectedIndex;
        setState(() {
          if (_selectedIndex != MainNavigationConfig.divisionAIndex &&
              _selectedIndex != MainNavigationConfig.divisionBIndex) {
            _selectedIndex = MainNavigationConfig.divisionAIndex;
          }
          nextIndex = _selectedIndex;
        });
        _trackScreenView(nextIndex);
        return;
      case 2:
        await _selectIndex(MainNavigationConfig.programIndex);
        return;
      case 3:
        await _selectIndex(MainNavigationConfig.predictIndex);
        return;
      case 4:
        await _showMobileMenu();
        return;
    }
  }

  int _mobileSelectedIndex() {
    if (_selectedIndex == MainNavigationConfig.divisionAIndex ||
        _selectedIndex == MainNavigationConfig.divisionBIndex) {
      return 1;
    }
    if (_selectedIndex == MainNavigationConfig.programIndex) return 2;
    if (_selectedIndex == MainNavigationConfig.predictIndex) return 3;
    if (_selectedIndex == MainNavigationConfig.homeIndex) return 0;
    return 4;
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
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help en informatie'),
                  onTap: () => Navigator.of(context).pop(98),
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
    } else if (selected == 98) {
      Navigator.pushNamed(context, '/help');
    } else {
      await _selectIndex(selected);
    }
  }

  void _showAnnouncement(bool loggedIn) {
    AnnouncementService.showAgain(context, isLoggedIn: loggedIn);
  }

  Future<void> _syncPredictionReminders() async {
    await _reminderService.syncMissingPredictionNotification(division: 'A');
    await _reminderService.syncMissingPredictionNotification(division: 'B');
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationCenterScreen(
          onOpenPrediction: (division, round) {
            _selectIndex(MainNavigationConfig.predictIndex);
          },
        ),
      ),
    );
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
              return _withAnalyticsConsentBanner(
                isDesktop: true,
                child: Scaffold(
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
                              onOpenNotifications: _openNotifications,
                              reminderService: _reminderService,
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
                ),
              );
            }

            return _withAnalyticsConsentBanner(
              isDesktop: false,
              child: Scaffold(
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
                    _NotificationBell(
                      service: _reminderService,
                      hasAnnouncement: _hasMelding,
                      onOpenNotifications: _openNotifications,
                      onShowAnnouncement: () => _showAnnouncement(loggedIn),
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
                body: _selectedIndex == MainNavigationConfig.divisionAIndex ||
                        _selectedIndex == MainNavigationConfig.divisionBIndex
                    ? _MobileDivisionsView(
                        selectedDivision: _selectedIndex ==
                                MainNavigationConfig.divisionBIndex
                            ? 'B'
                            : 'A',
                        onDivisionChanged: (division) {
                          final nextIndex = division == 'B'
                              ? MainNavigationConfig.divisionBIndex
                              : MainNavigationConfig.divisionAIndex;
                          setState(() {
                            _selectedIndex = nextIndex;
                          });
                          _trackScreenView(nextIndex);
                        },
                      )
                    : screens[_selectedIndex],
                bottomNavigationBar: NavigationBar(
                  selectedIndex: _mobileSelectedIndex(),
                  onDestinationSelected: _selectMobileDestination,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.leaderboard_outlined),
                      selectedIcon: Icon(Icons.leaderboard),
                      label: 'Divisies',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: 'Programma',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.edit_calendar_outlined),
                      selectedIcon: Icon(Icons.edit_calendar),
                      label: 'Voorspellen',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.more_horiz),
                      selectedIcon: Icon(Icons.more),
                      label: 'Meer',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _withAnalyticsConsentBanner({
    required Widget child,
    required bool isDesktop,
  }) {
    return Stack(
      children: [
        child,
        if (_showAnalyticsConsentBanner)
          _AnalyticsConsentBanner(
            isDesktop: isDesktop,
            onDenied: () => _setAnalyticsConsent(false),
            onAccepted: () => _setAnalyticsConsent(true),
            onMoreInfo: _openPrivacyInfo,
          ),
      ],
    );
  }
}

class _AnalyticsConsentBanner extends StatelessWidget {
  const _AnalyticsConsentBanner({
    required this.isDesktop,
    required this.onDenied,
    required this.onAccepted,
    required this.onMoreInfo,
  });

  final bool isDesktop;
  final VoidCallback onDenied;
  final VoidCallback onAccepted;
  final VoidCallback onMoreInfo;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = isDesktop ? 20.0 : 92.0;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        minimum: EdgeInsets.fromLTRB(14, 8, 14, bottomPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Material(
              elevation: 10,
              shadowColor: Colors.black26,
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 18 : 14,
                  14,
                  isDesktop ? 18 : 14,
                  14,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final text = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Analytics',
                          style: TextStyle(
                            color: Color(0xFF153B2A),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'We gebruiken Google Analytics om te begrijpen welke onderdelen van DerdeDiv worden gebruikt. We sturen geen naam, e-mailadres, gebruikersnaam of vrije tekst mee.',
                          style: TextStyle(
                            color: Color(0xFF5F6D64),
                            height: 1.3,
                          ),
                        ),
                      ],
                    );
                    final actions = Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment:
                          compact ? WrapAlignment.start : WrapAlignment.end,
                      children: [
                        TextButton(
                          onPressed: onDenied,
                          child: const Text('Niet toestaan'),
                        ),
                        TextButton(
                          onPressed: onMoreInfo,
                          child: const Text('Meer informatie'),
                        ),
                        FilledButton(
                          onPressed: onAccepted,
                          child: const Text('Toestaan'),
                        ),
                      ],
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          text,
                          const SizedBox(height: 10),
                          actions,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: text),
                        const SizedBox(width: 16),
                        actions,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
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
                height: 96,
                alignment: Alignment.center,
                child: const DerdeDivLogo.full(
                  width: 88,
                  height: 88,
                  responsive: false,
                ),
              ),
              const SizedBox(height: 18),
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
                      ? 'Je voorspellingen, poules en profiel staan klaar.'
                      : 'Bekijk standen en programma. Log in voor voorspellingen en poules.',
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

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({
    required this.service,
    required this.hasAnnouncement,
    required this.onOpenNotifications,
    required this.onShowAnnouncement,
  });

  final PredictionReminderService service;
  final bool hasAnnouncement;
  final VoidCallback onOpenNotifications;
  final VoidCallback onShowAnnouncement;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.unreadNotificationsStream(),
      builder: (context, snapshot) {
        final unread = unreadNotificationCount(
          snapshot.data?.docs.map(
                (doc) => UserNotificationRecord(id: doc.id, data: doc.data()),
              ) ??
              const [],
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                unread > 0 || hasAnnouncement
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_outlined,
              ),
              tooltip: 'Meldingen',
              onPressed: onOpenNotifications,
            ),
            if (unread > 0)
              Positioned(
                right: 7,
                top: 7,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MobileDivisionsView extends StatefulWidget {
  const _MobileDivisionsView({
    required this.selectedDivision,
    required this.onDivisionChanged,
  });

  final String selectedDivision;
  final ValueChanged<String> onDivisionChanged;

  @override
  State<_MobileDivisionsView> createState() => _MobileDivisionsViewState();
}

class _MobileDivisionsViewState extends State<_MobileDivisionsView> {
  late String _division;

  @override
  void initState() {
    super.initState();
    _division = widget.selectedDivision == 'B' ? 'B' : 'A';
  }

  @override
  void didUpdateWidget(covariant _MobileDivisionsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.selectedDivision == 'B' ? 'B' : 'A';
    if (next != _division) _division = next;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'A', label: Text('Divisie A')),
              ButtonSegment(value: 'B', label: Text('Divisie B')),
            ],
            selected: {_division},
            onSelectionChanged: (selection) {
              final value = selection.first;
              setState(() => _division = value);
              widget.onDivisionChanged(value);
            },
          ),
        ),
        Expanded(
          child: _division == 'B'
              ? const DivisionOverviewScreen(division: 'Derde Divisie B')
              : const DivisionOverviewScreen(division: 'Derde Divisie A'),
        ),
      ],
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
  final VoidCallback onOpenNotifications;
  final PredictionReminderService reminderService;

  const _DesktopHeader({
    required this.title,
    required this.loggedIn,
    required this.hasMelding,
    required this.isModerator,
    required this.onLogin,
    required this.onLogout,
    required this.onShowAnnouncement,
    required this.onModerator,
    required this.onOpenNotifications,
    required this.reminderService,
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
          _NotificationBell(
            service: reminderService,
            hasAnnouncement: hasMelding,
            onOpenNotifications: onOpenNotifications,
            onShowAnnouncement: onShowAnnouncement,
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
