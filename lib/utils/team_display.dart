import 'team_code_mapping.dart';

/// Canonical ‘mooie’ displaynaam uit ruwe naam of code.
String canonicalDisplayName(dynamic raw) {
  final s0 = (raw ?? '').toString().trim();
  if (s0.isEmpty) return '?';

  // Exacte code -> hou code (zoals ADO20, VVSB)
  if (teamCodeMapping.containsKey(s0)) return s0;
  if (codeToTeamName.containsKey(s0)) return codeToTeamName[s0]!;

  // Case-insensitive fallbacks
  final up = s0.toUpperCase();
  for (final k in teamCodeMapping.keys) {
    if (k.toUpperCase() == up) return k;
  }
  for (final k in codeToTeamName.keys) {
    if (k.toUpperCase() == up) return codeToTeamName[k]!;
  }

  return s0; // al nette naam
}

/// Logo-pad bouwen (case-sensitive: NIET uppercasen!)
String logoAssetFromDisplayName(String displayName) {
  var t = displayName.replaceAll(RegExp(r'\(.*?\)'), '').trim();

  // strip rare tekens, behoud echte hoofdletters/cijfers zodat assets matchen
  var clean = t
      .replaceAll('’', '')
      .replaceAll("'", '')
      .replaceAll('\u00A0', '')
      .replaceAll(' ', '')
      .replaceAll('/', '')
      .replaceAll('.', '')
      .replaceAll('-', '');

  // overrides voor lastige gevallen
  const overrides = {
    'ADO20': 'assets/images/logo_ADO20.png',
  };
  if (overrides.containsKey(clean)) return overrides[clean]!;

  return 'assets/images/logo_$clean.png';
}
