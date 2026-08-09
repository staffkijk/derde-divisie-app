import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:derde_divisie/core/design/app_design.dart';

class PredictionScore {
  const PredictionScore(this.home, this.away);

  final int home;
  final int away;

  String get label => '$home-$away';
}

class PredictionScoreGroup {
  const PredictionScoreGroup({
    required this.label,
    required this.scores,
  });

  final String label;
  final List<PredictionScore> scores;
}

class PredictionScorePicker extends StatelessWidget {
  const PredictionScorePicker({
    super.key,
    required this.homeScore,
    required this.awayScore,
    required this.locked,
    required this.onScoreSelected,
    required this.semanticLabel,
  });

  final int? homeScore;
  final int? awayScore;
  final bool locked;
  final ValueChanged<PredictionScore> onScoreSelected;
  final String semanticLabel;

  static const quickScores = <PredictionScore>[
    PredictionScore(3, 1),
    PredictionScore(2, 1),
    PredictionScore(1, 0),
    PredictionScore(0, 0),
    PredictionScore(1, 1),
    PredictionScore(2, 2),
    PredictionScore(0, 1),
    PredictionScore(1, 2),
    PredictionScore(1, 3),
  ];

  static const quickScoreGroups = <PredictionScoreGroup>[
    PredictionScoreGroup(
      label: 'Thuiswinst',
      scores: [
        PredictionScore(3, 1),
        PredictionScore(2, 1),
        PredictionScore(1, 0),
      ],
    ),
    PredictionScoreGroup(
      label: 'Gelijk',
      scores: [
        PredictionScore(0, 0),
        PredictionScore(1, 1),
        PredictionScore(2, 2),
      ],
    ),
    PredictionScoreGroup(
      label: 'Uitwinst',
      scores: [
        PredictionScore(0, 1),
        PredictionScore(1, 2),
        PredictionScore(1, 3),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ScoreBox(
          value: homeScore,
          locked: locked,
          label: '$semanticLabel thuisscore',
          onTap: () => _openPicker(context),
        ),
        const SizedBox(width: 6),
        const Text(
          '-',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 6),
        _ScoreBox(
          value: awayScore,
          locked: locked,
          label: '$semanticLabel uitscore',
          onTap: () => _openPicker(context),
        ),
      ],
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    if (locked) return;
    final selected = await showModalBottomSheet<PredictionScore>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PredictionScoreSheet(
        selectedHome: homeScore,
        selectedAway: awayScore,
      ),
    );
    if (selected != null) onScoreSelected(selected);
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({
    required this.value,
    required this.locked,
    required this.label,
    required this.onTap,
  });

  final int? value;
  final bool locked;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !locked,
      label: label,
      child: FocusableActionDetector(
        enabled: !locked,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (!locked) onTap();
              return null;
            },
          ),
        },
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: Container(
            width: 44,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: locked ? Colors.grey.shade100 : AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(
                color: locked ? Colors.grey.shade300 : AppColors.border,
              ),
            ),
            child: Text(
              value?.toString() ?? '',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PredictionScoreSheet extends StatefulWidget {
  const _PredictionScoreSheet({
    required this.selectedHome,
    required this.selectedAway,
  });

  final int? selectedHome;
  final int? selectedAway;

  @override
  State<_PredictionScoreSheet> createState() => _PredictionScoreSheetState();
}

class _PredictionScoreSheetState extends State<_PredictionScoreSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _homeController;
  late final TextEditingController _awayController;
  bool _manual = false;

  @override
  void initState() {
    super.initState();
    _homeController = TextEditingController(
      text: widget.selectedHome?.toString() ?? '',
    );
    _awayController = TextEditingController(
      text: widget.selectedAway?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _homeController.dispose();
    _awayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        },
        child: Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                Navigator.maybePop(context);
                return null;
              },
            ),
          },
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 4, 18, 18 + bottom),
            child: SingleChildScrollView(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 160),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Kies uitslag', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final group
                            in PredictionScorePicker.quickScoreGroups)
                          _ScoreGroup(
                            group: group,
                            selectedHome: widget.selectedHome,
                            selectedAway: widget.selectedAway,
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Anders'),
                          onPressed: () => setState(() => _manual = !_manual),
                        ),
                      ],
                    ),
                    if (_manual) ...[
                      const SizedBox(height: AppSpacing.md),
                      Form(
                        key: _formKey,
                        child: Row(
                          children: [
                            Expanded(
                              child: _ManualScoreField(
                                controller: _homeController,
                                label: 'Thuis',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _ManualScoreField(
                                controller: _awayController,
                                label: 'Uit',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.icon(
                        onPressed: _submitManual,
                        icon: const Icon(Icons.check_outlined),
                        label: const Text('Toepassen'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitManual() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      PredictionScore(
        int.parse(_homeController.text.trim()),
        int.parse(_awayController.text.trim()),
      ),
    );
  }
}

class _ScoreGroup extends StatelessWidget {
  const _ScoreGroup({
    required this.group,
    required this.selectedHome,
    required this.selectedAway,
  });

  final PredictionScoreGroup group;
  final int? selectedHome;
  final int? selectedAway;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 178),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
                child: Text(
                  group.label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final score in group.scores)
                    ChoiceChip(
                      selected: selectedHome == score.home &&
                          selectedAway == score.away,
                      label: Text(score.label),
                      onSelected: (_) => Navigator.pop(context, score),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualScoreField extends StatelessWidget {
  const _ManualScoreField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
      ),
      validator: (value) {
        final parsed = int.tryParse(value?.trim() ?? '');
        if (parsed == null) return 'Vul een geheel getal in';
        if (parsed < 0 || parsed > 20) return 'Gebruik 0 t/m 20';
        return null;
      },
    );
  }
}
