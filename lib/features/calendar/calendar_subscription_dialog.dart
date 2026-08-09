import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../data/config/season_config.dart';

enum CalendarScope { all, divisionA, divisionB, team }

class CalendarSubscriptionDialog extends StatefulWidget {
  const CalendarSubscriptionDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => const CalendarSubscriptionDialog(),
      );

  @override
  State<CalendarSubscriptionDialog> createState() =>
      _CalendarSubscriptionDialogState();
}

class _CalendarSubscriptionDialogState
    extends State<CalendarSubscriptionDialog> {
  CalendarScope _scope = CalendarScope.all;
  SeasonTeam? _team;

  String get _feedUrl {
    final origin = Uri.base.hasAuthority
        ? '${Uri.base.scheme}://${Uri.base.authority}'
        : 'https://derde-divisie-app.web.app';
    late final String path;
    switch (_scope) {
      case CalendarScope.all:
        path = 'alles.ics';
        break;
      case CalendarScope.divisionA:
        path = 'divisie-a.ics';
        break;
      case CalendarScope.divisionB:
        path = 'divisie-b.ics';
        break;
      case CalendarScope.team:
        path = 'team/${_team?.id ?? ''}.ics';
        break;
    }
    return '$origin/agenda/$path';
  }

  bool get _ready => _scope != CalendarScope.team || _team != null;

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const Key('calendar-subscription-dialog'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        title: const Text('Zet het programma in je agenda'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<CalendarScope>(
                  key: const Key('calendar-scope'),
                  value: _scope,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Programmakeuze',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: CalendarScope.all,
                        child: Text('Volledig programma Derde Divisie A en B')),
                    DropdownMenuItem(
                        value: CalendarScope.divisionA,
                        child: Text('Volledig programma Derde Divisie A')),
                    DropdownMenuItem(
                        value: CalendarScope.divisionB,
                        child: Text('Volledig programma Derde Divisie B')),
                    DropdownMenuItem(
                        value: CalendarScope.team,
                        child: Text('Programma van één club')),
                  ],
                  onChanged: (value) => setState(() {
                    _scope = value ?? CalendarScope.all;
                    if (_scope != CalendarScope.team) _team = null;
                  }),
                ),
                if (_scope == CalendarScope.team) ...[
                  const SizedBox(height: 16),
                  Autocomplete<SeasonTeam>(
                    key: const Key('calendar-team-picker'),
                    displayStringForOption: (team) => team.listLabel,
                    optionsBuilder: (value) {
                      final query = value.text.trim().toLowerCase();
                      return SeasonConfig.teamsInListOrder.where((team) =>
                          query.isEmpty ||
                          team.listLabel.toLowerCase().contains(query));
                    },
                    onSelected: (team) => setState(() => _team = team),
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) =>
                            TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Zoek en kies een club',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (_team != null) setState(() => _team = null);
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text('Kies je agenda-app',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _action('Apple Agenda', Icons.calendar_month, _openWebcal),
                  _action('Outlook / Microsoft 365', Icons.event, _openOutlook),
                  _action('Google Agenda', Icons.today, _openGoogle),
                  _action('Andere agenda', Icons.open_in_new, _openHttps),
                  _action('Kopieer abonnementslink', Icons.copy, _copy,
                      key: const Key('copy-calendar-link')),
                ]),
                const SizedBox(height: 16),
                const Text(
                  'Wedstrijdwijzigingen en uitslagen worden automatisch verwerkt. Het kan enige tijd duren voordat je agenda de laatste wijzigingen ophaalt.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF526057)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Google Agenda: kies de knop of kopieer de HTTPS-link en voeg die op calendar.google.com toe via Andere agenda’s > Via URL.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF667067)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Sluiten'))
        ],
      );

  Widget _action(String label, IconData icon, Future<void> Function() onTap,
          {Key? key}) =>
      OutlinedButton.icon(
          key: key,
          onPressed: _ready ? onTap : null,
          icon: Icon(icon),
          label: Text(label));

  Future<void> _launch(String url) async {
    if (!await launchUrlString(url, webOnlyWindowName: '_blank') && mounted) {
      _message('Openen is niet gelukt. Kopieer de abonnementslink handmatig.');
    }
  }

  Future<void> _openWebcal() =>
      _launch(_feedUrl.replaceFirst(RegExp(r'^https?'), 'webcal'));
  Future<void> _openHttps() => _launch(_feedUrl);
  Future<void> _openGoogle() => _launch(
      'https://calendar.google.com/calendar/r?cid=${Uri.encodeComponent(_feedUrl)}');
  Future<void> _openOutlook() => _launch(
      'https://outlook.live.com/calendar/0/addcalendar?url=${Uri.encodeComponent(_feedUrl)}&name=${Uri.encodeComponent('DerdeDiv programma')}');

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _feedUrl));
    if (mounted) _message('Abonnementslink gekopieerd.');
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
