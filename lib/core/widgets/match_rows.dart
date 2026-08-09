import 'package:flutter/material.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/core/widgets/match_status_badge.dart';
import 'package:derde_divisie/data/config/team_logo_assets.dart';

class MatchRowData {
  const MatchRowData({
    required this.homeTeam,
    required this.awayTeam,
    required this.status,
    this.homeTeamSlug = '',
    this.awayTeamSlug = '',
    this.centerLabel = 'vs',
  });

  final String homeTeam;
  final String awayTeam;
  final String homeTeamSlug;
  final String awayTeamSlug;
  final String centerLabel;
  final MatchStatus status;
}

class BaseMatchRow extends StatelessWidget {
  const BaseMatchRow({
    super.key,
    required this.data,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  final MatchRowData data;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? AppSpacing.sm : AppSpacing.md,
          vertical: dense ? AppSpacing.xs : AppSpacing.sm,
        ),
        child: compact ? _mobile() : _desktop(),
      ),
    );
  }

  Widget _desktop() {
    return Row(
      children: [
        Expanded(child: _team(data.homeTeam, data.homeTeamSlug, false)),
        const SizedBox(width: AppSpacing.sm),
        _center(),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _team(data.awayTeam, data.awayTeamSlug, true)),
        const SizedBox(width: AppSpacing.md),
        MatchStatusBadge(status: data.status),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.xs),
          trailing!,
        ],
      ],
    );
  }

  Widget _mobile() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _team(data.homeTeam, data.homeTeamSlug, false)),
            const SizedBox(width: AppSpacing.xs),
            _center(),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: _team(data.awayTeam, data.awayTeamSlug, true)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            MatchStatusBadge(status: data.status),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
      ],
    );
  }

  Widget _team(String name, String slug, bool end) {
    final asset =
        teamLogoAssetFromValues([slug, name]) ?? kDefaultTeamLogoAsset;
    final content = [
      SizedBox(
        width: 30,
        height: 30,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.shield_outlined,
            color: AppColors.primary,
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        child: Text(
          name,
          textAlign: end ? TextAlign.right : TextAlign.left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ];
    return Row(
      textDirection: end ? TextDirection.rtl : TextDirection.ltr,
      children: content,
    );
  }

  Widget _center() {
    return Container(
      constraints: const BoxConstraints(minWidth: 68),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Text(
        data.centerLabel,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class CompactMatchRow extends BaseMatchRow {
  const CompactMatchRow({
    super.key,
    required super.data,
    super.trailing,
    super.onTap,
  }) : super(dense: true);
}

class PublicMatchRow extends BaseMatchRow {
  const PublicMatchRow({
    super.key,
    required super.data,
    super.trailing,
    super.onTap,
  });
}

class PredictionMatchRow extends BaseMatchRow {
  const PredictionMatchRow({
    super.key,
    required super.data,
    super.trailing,
    super.onTap,
  });
}

class TeamPredictionMatchRow extends BaseMatchRow {
  const TeamPredictionMatchRow({
    super.key,
    required super.data,
    super.trailing,
    super.onTap,
  });
}

class ModeratorMatchRow extends BaseMatchRow {
  const ModeratorMatchRow({
    super.key,
    required super.data,
    super.trailing,
    super.onTap,
  });
}

class ScoreBadge extends StatelessWidget {
  const ScoreBadge({super.key, required this.label, this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: .12)
            : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}
