import 'package:flutter/material.dart';
import 'package:derde_divisie/core/widgets/team_logo.dart';
import 'package:derde_divisie/data/config/season_config.dart';

final Map<String, String> clubLogoMap = SeasonConfig.logoMapByTeamCode;

Widget getLogo(String clubnaam, {double size = 24}) {
  return TeamLogo(
    teamName: clubnaam,
    assetPath: SeasonConfig.logoPathForTeamOrNull(clubnaam),
    size: size,
  );
}
