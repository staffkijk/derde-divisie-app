import 'package:cloud_functions/cloud_functions.dart';
Future<void> verwerkEindstandPunten(String divisieLetter) async {
  await FirebaseFunctions.instanceFor(region:'europe-west1').httpsCallable('processFinalStandings')
    .call<void>({'division':divisieLetter});
}
Future<void> verwerkEindstandPuntenBeide() async {
  await verwerkEindstandPunten('A');await verwerkEindstandPunten('B');
}
