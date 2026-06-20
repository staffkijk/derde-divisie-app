// lib/updates/update_log_button.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'update_service.dart';
import 'app_update.dart';
import 'update_log_screen.dart';

class UpdateLogButton extends StatelessWidget {
  final UpdateService _service = UpdateService();

  /// Mag de admin-tools zien in het log
  final bool isAdmin;

  /// Optioneel: forceer een icoonkleur (handig op AppBar)
  final Color? iconColor;

  /// Optioneel: forceer de badge-kleur (default: rood)
  final Color? badgeColor;

  UpdateLogButton({
    super.key,
    this.isAdmin = false,
    this.iconColor,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    // Contrasterende kleur voor het icoon op de AppBar (val terug op wit)
    final Color resolvedIconColor = iconColor
        ?? Theme.of(context).appBarTheme.actionsIconTheme?.color
        ?? Theme.of(context).appBarTheme.iconTheme?.color
        ?? Colors.white;

    // Badge-kleur
    final Color resolvedBadgeColor = badgeColor ?? Colors.red;

    return StreamBuilder<AppUpdate?>(
      stream: _service.streamLatestUpdate(),
      builder: (context, latestSnap) {
        final latest = latestSnap.data;

        return StreamBuilder<Timestamp?>(
          stream: _service.streamUserLastSeen(),
          builder: (context, seenSnap) {
            final lastSeen = seenSnap.data;
            final latestTs = latest?.createdAt;

            final hasUnseen = (latest != null && latestTs != null)
                ? (lastSeen == null || latestTs.compareTo(lastSeen) > 0)
                : false;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Updates',
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UpdateLogScreen(
                          service: _service,
                          isAdmin: isAdmin,
                        ),
                      ),
                    );
                    if (latestTs != null) {
                      await _service.markUpdatesSeen(upTo: latestTs);
                    }
                  },
                  // 🔔 Bel-icoon met expliciete kleur (werkt betrouwbaar op mobiel/PWA)
                  icon: Icon(
                    Icons.notifications,
                    color: resolvedIconColor,
                    size: 26,
                  ),
                ),
                if (hasUnseen)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: resolvedBadgeColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withAlpha(230),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
