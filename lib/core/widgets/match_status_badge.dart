import 'package:flutter/material.dart';

import 'package:derde_divisie/core/design/app_design.dart';

enum MatchStatus {
  scheduled,
  finished,
  postponed,
  cancelled,
  abandoned,
}

extension MatchStatusPresentation on MatchStatus {
  String get firestoreValue {
    switch (this) {
      case MatchStatus.scheduled:
        return 'scheduled';
      case MatchStatus.finished:
        return 'finished';
      case MatchStatus.postponed:
        return 'postponed';
      case MatchStatus.cancelled:
        return 'cancelled';
      case MatchStatus.abandoned:
        return 'abandoned';
    }
  }

  String get label {
    switch (this) {
      case MatchStatus.scheduled:
        return 'Gepland';
      case MatchStatus.finished:
        return 'Afgelopen';
      case MatchStatus.postponed:
        return 'In te halen';
      case MatchStatus.cancelled:
        return 'Afgelast';
      case MatchStatus.abandoned:
        return 'Gestaakt';
    }
  }

  Color get color {
    switch (this) {
      case MatchStatus.scheduled:
        return AppColors.primaryDark;
      case MatchStatus.finished:
        return AppColors.primary;
      case MatchStatus.postponed:
        return AppColors.info;
      case MatchStatus.cancelled:
      case MatchStatus.abandoned:
        return AppColors.danger;
    }
  }
}

MatchStatus parseMatchStatus(dynamic value) {
  switch (value?.toString().trim().toLowerCase()) {
    case 'finished':
    case 'final':
    case 'played':
    case 'afgelopen':
      return MatchStatus.finished;
    case 'postponed':
    case 'uitgesteld':
      return MatchStatus.postponed;
    case 'cancelled':
    case 'afgelast':
      return MatchStatus.cancelled;
    case 'abandoned':
    case 'gestaakt':
      return MatchStatus.abandoned;
    case 'scheduled':
    case 'planned':
    case 'gepland':
    default:
      return MatchStatus.scheduled;
  }
}

class MatchStatusBadge extends StatelessWidget {
  const MatchStatusBadge({super.key, required this.status});

  final MatchStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: status.color.withValues(alpha: .24)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
