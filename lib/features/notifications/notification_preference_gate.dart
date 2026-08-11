import 'package:flutter/widgets.dart';

import 'package:derde_divisie/data/models/notification_preferences.dart';
import 'package:derde_divisie/data/services/notification_preferences_service.dart';

class NotificationPreferenceGate extends StatefulWidget {
  const NotificationPreferenceGate({
    super.key,
    required this.builder,
    this.service,
  });

  final NotificationPreferencesStore? service;
  final Widget Function(
    BuildContext context,
    NotificationPreferences preferences,
  ) builder;

  @override
  State<NotificationPreferenceGate> createState() =>
      _NotificationPreferenceGateState();
}

class _NotificationPreferenceGateState
    extends State<NotificationPreferenceGate> {
  late final NotificationPreferencesStore _service;
  late final Stream<NotificationPreferences> _stream;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? NotificationPreferencesService();
    _stream = _service.watch();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NotificationPreferences>(
      stream: _stream,
      builder: (context, snapshot) {
        final preferences = snapshot.data;
        if (preferences == null || !preferences.missingPredictionReminders) {
          return const SizedBox.shrink();
        }
        return widget.builder(context, preferences);
      },
    );
  }
}
