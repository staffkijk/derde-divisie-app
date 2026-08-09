import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/config/team_logo_assets.dart';

class TeamLogo extends StatelessWidget {
  const TeamLogo({
    super.key,
    this.teamName,
    this.teamSlug,
    this.assetPath,
    this.size = 32,
    this.semanticLabel,
    this.padding = 2,
  });

  final String? teamName;
  final String? teamSlug;
  final String? assetPath;
  final double size;
  final String? semanticLabel;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final path = _assetPath;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = kIsWeb ? null : math.max(1, (size * dpr).round());

    return Semantics(
      image: true,
      label: semanticLabel ?? _semanticLabel,
      child: SizedBox.square(
        dimension: size,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Image.asset(
            path,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            errorBuilder: (_, __, ___) => Image.asset(
              kDefaultTeamLogoAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              cacheWidth: cacheSize,
              cacheHeight: cacheSize,
              errorBuilder: (_, __, ___) => Icon(
                Icons.shield_outlined,
                size: size * .72,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _assetPath {
    if (assetPath != null && assetPath!.trim().isNotEmpty) {
      return assetPath!.trim();
    }
    return teamLogoAssetFromValues([teamSlug, teamName]) ??
        SeasonConfig.logoPathForTeamOrNull(teamName ?? '') ??
        kDefaultTeamLogoAsset;
  }

  String get _semanticLabel {
    final label = teamName?.trim();
    if (label == null || label.isEmpty) return 'Clublogo';
    return 'Clublogo $label';
  }
}
