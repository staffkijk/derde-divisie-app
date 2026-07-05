import 'package:flutter/material.dart';

import 'package:derde_divisie/core/design/app_design.dart';
import 'package:derde_divisie/features/derde_divisie/program_screen.dart';

class UnifiedProgramScreen extends StatefulWidget {
  const UnifiedProgramScreen({super.key, this.initialDivision = 'A'});

  final String initialDivision;

  @override
  State<UnifiedProgramScreen> createState() => _UnifiedProgramScreenState();
}

class _UnifiedProgramScreenState extends State<UnifiedProgramScreen> {
  late String _division;
  bool _showAllMatches = false;

  @override
  void initState() {
    super.initState();
    _division = widget.initialDivision == 'B' ? 'B' : 'A';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.matchContentMaxWidth,
                ),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: [
                      const SizedBox(
                        width: 270,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Programma',
                              style: AppTextStyles.sectionTitle,
                            ),
                            SizedBox(height: AppSpacing.xxs),
                            Text(
                              'Programma en uitslagen per speelronde.',
                              style: AppTextStyles.bodyMuted,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'A',
                            label: Text('Divisie A'),
                          ),
                          ButtonSegment(
                            value: 'B',
                            label: Text('Divisie B'),
                          ),
                        ],
                        selected: {_division},
                        onSelectionChanged: (selection) {
                          setState(() => _division = selection.first);
                        },
                      ),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Speelronde'),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Alle wedstrijden'),
                          ),
                        ],
                        selected: {_showAllMatches},
                        onSelectionChanged: (selection) {
                          setState(() => _showAllMatches = selection.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey('$_division-$_showAllMatches'),
              child: ProgramScreen(
                division: _division,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
