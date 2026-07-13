import 'package:flutter/material.dart';

import 'package:derde_divisie/core/widgets/team_logo.dart';

class VoorspelWedstrijdCard extends StatelessWidget {
  final String thuisteam;
  final String uitteam;
  final String datum;

  final TextEditingController thuisController;
  final TextEditingController uitController;

  /// Als true: invoer blokkeren (deadline verstreken).
  final bool isDisabled;

  /// Officiële uitslag (kan null zijn)
  final int? werkelijkeThuis;
  final int? werkelijkeUit;

  /// Behaalde punten van de gebruiker (alleen zinvol als officiële uitslag bekend is)
  final int? behaaldePunten;

  /// ✅ NIEUW: de eigen voorspelling van de gebruiker
  final int? eigenVoorspellingThuis;
  final int? eigenVoorspellingUit;

  final Function(String)? onThuisScoreChanged;
  final Function(String)? onUitScoreChanged;

  const VoorspelWedstrijdCard({
    super.key,
    required this.thuisteam,
    required this.uitteam,
    required this.datum,
    required this.thuisController,
    required this.uitController,
    this.isDisabled = false,
    this.werkelijkeThuis,
    this.werkelijkeUit,
    this.behaaldePunten,
    this.eigenVoorspellingThuis, // <-- nieuw
    this.eigenVoorspellingUit, // <-- nieuw
    this.onThuisScoreChanged,
    this.onUitScoreChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool uitslagIngevuld =
        werkelijkeThuis != null && werkelijkeUit != null;

    final bool heeftEigenVoorspelling =
        eigenVoorspellingThuis != null && eigenVoorspellingUit != null;

    // Let op: punten alleen tonen als er een officiële uitslag is
    final bool puntenBeschikbaar = uitslagIngevuld && behaaldePunten != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Datum
            Text(
              datum,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // Rij met teams + midden (scorevelden of slotje)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTeamColumn(thuisteam),
                isDisabled ? _buildLockCenter() : _buildScoreFields(),
                _buildTeamColumn(uitteam),
              ],
            ),

            // Onderregels: uitslag / eigen voorspelling / punten / status
            const SizedBox(height: 12),

            if (isDisabled && uitslagIngevuld) ...[
              Text(
                'Uitslag: $werkelijkeThuis - $werkelijkeUit',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              if (puntenBeschikbaar) ...[
                const SizedBox(height: 6),
                Text(
                  'Behaalde punten: +$behaaldePunten',
                  style: const TextStyle(fontSize: 13, color: Colors.green),
                ),
              ],
              if (heeftEigenVoorspelling) ...[
                const SizedBox(height: 6),
                Text(
                  'Jouw voorspelling: $eigenVoorspellingThuis - $eigenVoorspellingUit',
                  style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
              ],
            ] else if (isDisabled &&
                !uitslagIngevuld &&
                heeftEigenVoorspelling) ...[
              Text(
                'Jouw voorspelling: $eigenVoorspellingThuis - $eigenVoorspellingUit',
                style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
              ),
            ] else if (isDisabled &&
                !uitslagIngevuld &&
                !heeftEigenVoorspelling) ...[
              Text(
                'Gesloten',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeamColumn(String teamName) {
    return SizedBox(
      width: 100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TeamLogo(
            teamName: teamName,
            size: 48,
            padding: 0,
          ),
          const SizedBox(height: 6),
          Text(
            teamName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreFields() {
    return SizedBox(
      width: 90,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildScoreField(thuisController, onThuisScoreChanged, enabled: true),
          const SizedBox(width: 6),
          const Text('-', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          _buildScoreField(uitController, onUitScoreChanged, enabled: true),
        ],
      ),
    );
  }

  Widget _buildLockCenter() {
    return Tooltip(
      message: 'Je kunt niet meer voorspellen voor deze wedstrijd.',
      child: Column(
        children: const [
          Icon(Icons.lock, color: Colors.grey),
          SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildScoreField(
    TextEditingController controller,
    Function(String)? onChanged, {
    required bool enabled,
  }) {
    return SizedBox(
      width: 32,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        enabled: enabled, // na deadline: velden disabled in het scherm zelf
        onChanged: onChanged,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(vertical: 6),
          isDense: true,
          counterText: '',
        ),
        maxLength: 2,
      ),
    );
  }
}
