import 'dart:async';

import 'package:flutter/material.dart';

import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/models/notification_preferences.dart';
import 'package:derde_divisie/data/services/notification_preferences_service.dart';

class PredictionReminderPreferencesPanel extends StatefulWidget {
  const PredictionReminderPreferencesPanel({
    super.key,
    this.service,
    this.onChanged,
  });

  final NotificationPreferencesStore? service;
  final ValueChanged<NotificationPreferences>? onChanged;

  @override
  State<PredictionReminderPreferencesPanel> createState() =>
      _PredictionReminderPreferencesPanelState();
}

class _PredictionReminderPreferencesPanelState
    extends State<PredictionReminderPreferencesPanel> {
  late final NotificationPreferencesStore _service;
  StreamSubscription<NotificationPreferences>? _subscription;
  NotificationPreferences _preferences = const NotificationPreferences();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? NotificationPreferencesService();
    _subscription = _service.watch().listen((preferences) {
      if (!mounted || _saving) return;
      setState(() {
        _preferences = preferences;
        _loading = false;
      });
      widget.onChanged?.call(preferences);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _save(NotificationPreferences next) async {
    if (_saving || next.toMap().toString() == _preferences.toMap().toString()) {
      return;
    }
    final previous = _preferences;
    setState(() {
      _preferences = next;
      _saving = true;
    });
    widget.onChanged?.call(next);

    try {
      final result = await _service.save(
        next,
        wasMissingPredictionRemindersEnabled:
            previous.missingPredictionReminders,
      );
      if (!result.preferencesSaved) throw StateError('Niet ingelogd');
      if (!mounted) return;
      if (!result.oldRemindersRemoved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'De voorkeur is opgeslagen, maar oude herinneringen konden niet worden verwijderd.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _preferences = previous);
      widget.onChanged?.call(previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meldingsinstellingen opslaan mislukt')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final enabled = _preferences.missingPredictionReminders;
    final selectedIds = _preferences.selectedTeamIds.toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Voorspellingsherinneringen',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Herinnering ontbrekende voorspellingen'),
          subtitle: const Text(
            'Ontvang een melding als je voor een komende speelronde nog niet alles hebt voorspeld.',
          ),
          value: enabled,
          onChanged: _saving
              ? null
              : (value) => _save(
                    _preferences.copyWith(
                      missingPredictionReminders: value,
                    ),
                  ),
        ),
        AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: !enabled || _saving,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      selected: _preferences.divisionA,
                      label: const Text('Derde Divisie A'),
                      onSelected: (value) =>
                          _save(_preferences.copyWith(divisionA: value)),
                    ),
                    FilterChip(
                      selected: _preferences.divisionB,
                      label: const Text('Derde Divisie B'),
                      onSelected: (value) =>
                          _save(_preferences.copyWith(divisionB: value)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<NotificationTeamScope>(
                  value: _preferences.teamScope,
                  decoration: const InputDecoration(labelText: 'Teamvoorkeur'),
                  items: const [
                    DropdownMenuItem(
                      value: NotificationTeamScope.all,
                      child: Text('Alle teams / alle wedstrijden'),
                    ),
                    DropdownMenuItem(
                      value: NotificationTeamScope.favorite,
                      child: Text('Alleen favoriete club'),
                    ),
                    DropdownMenuItem(
                      value: NotificationTeamScope.selected,
                      child: Text('Specifieke geselecteerde teams'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _save(_preferences.copyWith(teamScope: value));
                    }
                  },
                ),
                if (_preferences.teamScope ==
                    NotificationTeamScope.selected) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final team in SeasonConfig.teamsInListOrder)
                        FilterChip(
                          selected: selectedIds.contains(team.id),
                          label: Text(team.listLabel),
                          onSelected: (value) {
                            final next = selectedIds.toSet();
                            value ? next.add(team.id) : next.remove(team.id);
                            _save(_preferences.copyWith(
                              selectedTeamIds: next.toList()..sort(),
                            ));
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
