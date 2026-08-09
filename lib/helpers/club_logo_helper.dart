import 'package:flutter/material.dart';
import 'package:derde_divisie/data/config/season_config.dart';

final Map<String, String> clubLogoMap = SeasonConfig.logoMapByTeamCode;

Widget getLogo(String clubnaam, {double size = 24}) {
  final String? imagePath = SeasonConfig.logoPathForTeamOrNull(clubnaam);
  if (imagePath != null) {
    return Image.asset(
      imagePath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  } else {
    return Icon(Icons.sports_soccer, size: size);
  }
}
