import 'package:flutter/material.dart';

const predictionsRankingsRoute = '/voorspellen/ranglijsten';
const poulesOverviewRoute = '/poules';

class RankingAppBar extends AppBar {
  RankingAppBar({
    super.key,
    required BuildContext context,
    required String title,
    required String fallbackRoute,
    super.actions,
  }) : super(
          title: Text(title),
          automaticallyImplyLeading: false,
          leading: IconButton(
            key: const Key('ranking-back-button'),
            tooltip: 'Terug',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => _goBack(context, fallbackRoute),
          ),
        );

  static Future<void> _goBack(
    BuildContext context,
    String fallbackRoute,
  ) async {
    final didPop = await Navigator.of(context).maybePop();
    if (!didPop && context.mounted) {
      await Navigator.of(context).pushReplacementNamed(fallbackRoute);
    }
  }
}
