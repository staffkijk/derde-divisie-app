import 'package:flutter/material.dart';

enum DerdeDivLogoVariant { compact, full }

class DerdeDivLogo extends StatelessWidget {
  static const compactAsset = 'assets/logo_dd.png';
  static const fullAsset = 'assets/logo_derdediv.png';

  final DerdeDivLogoVariant variant;
  final double? width;
  final double? height;
  final bool responsive;
  final String? semanticLabel;

  const DerdeDivLogo({
    super.key,
    this.variant = DerdeDivLogoVariant.full,
    this.width,
    this.height,
    this.responsive = true,
    this.semanticLabel = 'DerdeDiv logo',
  });

  const DerdeDivLogo.compact({
    super.key,
    this.width,
    this.height,
    this.semanticLabel = 'DerdeDiv logo',
  })  : variant = DerdeDivLogoVariant.compact,
        responsive = false;

  const DerdeDivLogo.full({
    super.key,
    this.width,
    this.height,
    this.responsive = true,
    this.semanticLabel = 'DerdeDiv logo',
  }) : variant = DerdeDivLogoVariant.full;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldUseCompact = variant == DerdeDivLogoVariant.compact ||
            (responsive &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth < 132);
        final asset = shouldUseCompact ? compactAsset : fullAsset;

        return Image.asset(
          asset,
          width: width,
          height: height,
          fit: BoxFit.contain,
          semanticLabel: semanticLabel,
        );
      },
    );
  }
}
