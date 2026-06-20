// lib/moderator/moderator_tools_screen.dart
import 'package:flutter/material.dart';
import 'package:derde_divisie/helpers/fake_data_generator.dart';
import 'package:derde_divisie/moderator/mod_tools.dart' as tools;

class ModeratorToolsScreen extends StatefulWidget {
  const ModeratorToolsScreen({super.key});

  @override
  State<ModeratorToolsScreen> createState() => _ModeratorToolsScreenState();
}

class _ModeratorToolsScreenState extends State<ModeratorToolsScreen> {
  bool _isBusy = false;

  Future<void> _runTool({
    required Future<void> Function() action,
    required String successMessage,
    required String errorPrefix,
  }) async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
    });

    try {
      await action();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorPrefix: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    String confirmText = 'Uitvoeren',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderator Tools'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('Controle'),
            _buildButton(
              label: 'Volledige eindcontrole uitvoeren',
              icon: Icons.fact_check_outlined,
              color: Colors.indigo,
              onPressed: _isBusy
                  ? null
                  : () async {
                      final confirmed = await _confirmAction(
                        title: 'Volledige eindcontrole uitvoeren?',
                        message:
                            'Deze actie controleert users, voorspellingen, eindstandpunten, standen, periodestanden en poules. Er worden geen punten aangepast. Het rapport komt in sync_logs/eindcontrole_laatste en bevat criticalByType, warningByType en issuesByType.',
                        confirmText: 'Controle starten',
                      );

                      if (!confirmed) return;

                      await _runTool(
                        action: tools.voerVolledigeEindcontroleAuditUit,
                        successMessage:
                            'Volledige eindcontrole afgerond. Bekijk sync_logs/eindcontrole_laatste in Firestore.',
                        errorPrefix: 'Fout bij volledige eindcontrole',
                      );
                    },
            ),

            const Divider(height: 24, thickness: 1),

            _sectionTitle('Veilig herstel'),
            _buildButton(
              label: 'Herstel algemene voorspellingen + usertotalen',
              icon: Icons.calculate_outlined,
              color: Colors.deepPurple,
              onPressed: _isBusy
                  ? null
                  : () async {
                      final confirmed = await _confirmAction(
                        title: 'Algemene voorspellingen herstellen?',
                        message:
                            'Deze actie herstelt alle algemene voorspellingen en bouwt users.punten_A, users.punten_B, users.totalen en users.points opnieuw op. Timestamp wordt niet gebruikt om voorspellingen af te keuren. Standen, periodestanden en poules worden niet aangepast.',
                        confirmText: 'Herstellen',
                      );

                      if (!confirmed) return;

                      await _runTool(
                        action:
                            tools.herstelAlleAlgemeneVoorspellingenEnUserTotalen,
                        successMessage:
                            'Algemene voorspellingen en usertotalen zijn hersteld.',
                        errorPrefix:
                            'Fout bij herstel algemene voorspellingen en usertotalen',
                      );
                    },
            ),
            _buildButton(
              label: 'Herstel alle poulepunten',
              icon: Icons.groups_2_outlined,
              color: Colors.teal,
              onPressed: _isBusy
                  ? null
                  : () async {
                      final confirmed = await _confirmAction(
                        title: 'Alle poulepunten herstellen?',
                        message:
                            'Deze actie herberekent poule_predictions, poule_voorspellingen, predictions en de punten op poules/{pouleId}/deelnemers. Timestamp wordt niet gebruikt om voorspellingen af te keuren.',
                        confirmText: 'Herstellen',
                      );

                      if (!confirmed) return;

                      await _runTool(
                        action: tools.herstelAllePoulePunten,
                        successMessage: 'Alle poulepunten zijn hersteld.',
                        errorPrefix: 'Fout bij herstel poulepunten',
                      );
                    },
            ),
            _buildButton(
              label: 'Herstel periodestanden',
              icon: Icons.table_chart_outlined,
              color: Colors.brown,
              onPressed: _isBusy
                  ? null
                  : () async {
                      final confirmed = await _confirmAction(
                        title: 'Periodestanden herstellen?',
                        message:
                            'Deze actie herberekent periodestanden/dda en periodestanden/ddb voor periode 1, 2 en 3 op basis van matches. Bestaande periodestanddocs in deze periodecollecties worden vervangen.',
                        confirmText: 'Herstellen',
                      );

                      if (!confirmed) return;

                      await _runTool(
                        action: tools.herstelAllePeriodestanden,
                        successMessage: 'Periodestanden zijn hersteld.',
                        errorPrefix: 'Fout bij herstel periodestanden',
                      );
                    },
            ),
            _buildButton(
              label: 'Markeer voorspellingen zonder wedstrijdId ongeldig',
              icon: Icons.rule_folder_outlined,
              color: Colors.blueGrey,
              onPressed: _isBusy
                  ? null
                  : () async {
                      final confirmed = await _confirmAction(
                        title:
                            'Voorspellingen zonder wedstrijdId ongeldig markeren?',
                        message:
                            'Deze actie verwijdert niets. Voorspellingen zonder wedstrijdId worden gemarkeerd met ongeldig: true en auditIgnored: true, zodat ze niet langer als critical meetellen.',
                        confirmText: 'Markeren',
                      );

                      if (!confirmed) return;

                      await _runTool(
                        action: tools
                            .markeerVoorspellingenZonderWedstrijdIdOngeldig,
                        successMessage:
                            'Voorspellingen zonder wedstrijdId zijn gemarkeerd.',
                        errorPrefix:
                            'Fout bij markeren voorspellingen zonder wedstrijdId',
                      );
                    },
            ),
            _buildButton(
              label: 'Herstel speelronde 18 A',
              icon: Icons.build_circle_outlined,
              color: Colors.blue,
              onPressed: _isBusy
                  ? null
                  : () async {
                      final confirmed = await _confirmAction(
                        title: 'Speelronde 18 A herstellen?',
                        message:
                            'Deze actie verwerkt specifiek de hardcoded herstelactie voor speelronde 18 A. Gebruik deze alleen voor de eerder gevonden correctie.',
                        confirmText: 'Herstellen',
                      );

                      if (!confirmed) return;

                      await _runTool(
                        action: tools.herstelVoorspellingenSpeelronde18A,
                        successMessage:
                            'Speelronde 18 A is opnieuw verwerkt.',
                        errorPrefix: 'Fout bij herstel speelronde 18 A',
                      );
                    },
            ),

            const Divider(height: 24, thickness: 1),

            _sectionTitle('Algemene tools'),
            _buildButton(
              label: 'Sync Tools',
              icon: Icons.sync,
              color: Colors.green,
              onPressed: _isBusy
                  ? null
                  : () async {
                      final confirmed = await _confirmAction(
                        title: 'Alle wedstrijden herberekenen?',
                        message:
                            'Let op: deze actie roept de volledige wedstrijdverwerking aan. Gebruik dit alleen als standen, periodestanden en voorspellingen opnieuw verwerkt mogen worden.',
                        confirmText: 'Herberekenen',
                      );

                      if (!confirmed) return;

                      await _runTool(
                        action: tools.herberekenAlleWedstrijden,
                        successMessage: 'Sync afgerond.',
                        errorPrefix: 'Fout bij sync',
                      );
                    },
            ),
            _buildButton(
              label: 'Eenmalige voorspel-sync',
              icon: Icons.group_add,
              color: Colors.green,
              onPressed: _isBusy ? null : () {},
            ),
            _buildButton(
              label: 'Push updates naar clients',
              icon: Icons.upload,
              color: Colors.green,
              onPressed: _isBusy ? null : () {},
            ),

            const Divider(height: 24, thickness: 1),

            _sectionTitle('Einde seizoen'),
            _buildButton(
              label: 'Einde seizoen: verwerk eindstand (A & B)',
              icon: Icons.flag_circle,
              color: Colors.green,
              onPressed: _isBusy
                  ? null
                  : () async {
                      final confirmed = await _confirmAction(
                        title: 'Eindstandpunten verwerken?',
                        message:
                            'Deze actie verwerkt de eindstandpunten voor Divisie A en B.',
                        confirmText: 'Verwerken',
                      );

                      if (!confirmed) return;

                      await _runTool(
                        action: tools.verwerkEindstandPuntenBeide,
                        successMessage:
                            'Eindstandpunten A & B zijn verwerkt.',
                        errorPrefix: 'Fout bij verwerken eindstandpunten',
                      );
                    },
            ),

            const Divider(height: 24, thickness: 1),

            _sectionTitle('Testdata'),
            _buildButton(
              label: 'Fake Data Generator',
              icon: Icons.people_alt_outlined,
              color: Colors.orange,
              onPressed: _isBusy
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SeedBulkFakeV2Screen(),
                        ),
                      );
                    },
            ),

            const Divider(height: 24, thickness: 1),

            _sectionTitle('Gevaarlijke acties'),
            _buildButton(
              label: 'Reset eindstandpunten (A & B)',
              icon: Icons.refresh,
              color: Colors.redAccent,
              onPressed: _isBusy
                  ? null
                  : () async {
                      final confirmed = await _confirmAction(
                        title: 'Reset uitvoeren?',
                        message:
                            'Let op: deze knop voert nu een harde reset en herberekening uit. Gebruik dit alleen als je exact weet wat je doet.',
                        confirmText: 'Resetten',
                      );

                      if (!confirmed) return;

                      await _runTool(
                        action: tools.hardeResetEnHerberekenAlles,
                        successMessage: 'Reset uitgevoerd.',
                        errorPrefix: 'Fout bij reset',
                      );
                    },
            ),
            _buildButton(
              label: 'VOLLEDIGE RESET (alles naar 0)',
              icon: Icons.delete_forever,
              color: Colors.red,
              onPressed: _isBusy
                  ? null
                  : () async {
                      final confirmed = await _confirmAction(
                        title: 'Volledige reset uitvoeren?',
                        message:
                            'Deze actie zet gebruikerspunten en poulepunten terug en rekent daarna alles opnieuw door. Dit is een zware actie.',
                        confirmText: 'Volledige reset',
                      );

                      if (!confirmed) return;

                      await _runTool(
                        action: tools.hardeResetEnHerberekenAlles,
                        successMessage: 'Volledige reset uitgevoerd.',
                        errorPrefix: 'Fout bij volledige reset',
                      );
                    },
            ),

            if (_isBusy) ...[
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Bezig met verwerken...'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withOpacity(0.45),
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        onPressed: onPressed,
      ),
    );
  }
}