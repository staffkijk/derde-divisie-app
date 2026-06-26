import 'package:flutter/foundation.dart';

@immutable
class SeasonTeam {
  const SeasonTeam({
    required this.id,
    required this.name,
    required this.division,
    required this.logoFileName,
    this.displayName,
    this.aliases = const [],
  });

  final String id;
  final String name;
  final String? displayName;
  final String division;
  final String logoFileName;
  final List<String> aliases;

  String get label => displayName ?? name;

  String get logoPath => 'assets/images/$logoFileName';

  bool matches(String value) {
    final input = SeasonConfig.normalizeTeamKey(value);

    if (input == SeasonConfig.normalizeTeamKey(id)) return true;
    if (input == SeasonConfig.normalizeTeamKey(name)) return true;
    if (input == SeasonConfig.normalizeTeamKey(label)) return true;

    for (final alias in aliases) {
      if (input == SeasonConfig.normalizeTeamKey(alias)) return true;
    }

    return false;
  }
}

class SeasonConfig {
  const SeasonConfig._();

  static const String activeSeasonId = '2026-2027';
  static const String activeSeasonLabel = '2026/2027';

  static const String divisionA = 'A';
  static const String divisionB = 'B';

  static const String divisionAName = 'Derde Divisie A';
  static const String divisionBName = 'Derde Divisie B';

  /// Tijdelijk true zolang de definitieve A/B-indeling nog niet verwerkt is.
  /// Nu: eerste 18 teams uit de centrale lijst = A, laatste 18 = B.
  static const bool useProvisionalDivisionSplit = true;

  static const List<SeasonTeam> teams = [
    SeasonTeam(
      id: 'acv',
      name: 'ACV',
      division: divisionA,
      logoFileName: 'logo_ACV.png',
      aliases: ['ACV Assen'],
    ),
    SeasonTeam(
      id: 'ado20',
      name: 'ADO20',
      displayName: 'ADO’20',
      division: divisionA,
      logoFileName: 'logo_ADO20.png',
      aliases: ['ADO 20', 'ADO’20', 'ADO\'20', 'ADO20 Heemskerk'],
    ),
    SeasonTeam(
      id: 'blauw_geel_38',
      name: 'Blauw Geel 38',
      displayName: 'Blauw Geel’38',
      division: divisionA,
      logoFileName: 'logo_BlauwGeel38.png',
      aliases: [
        'Blauw Geel38',
        'Blauw Geel 38 JUMBO',
        'Blauw Geel38 JUMBO',
        'Blauw Geel’38',
        'Blauw Geel\'38',
        'Blauw Geel ’38/JUMBO',
      ],
    ),
    SeasonTeam(
      id: 'dvs33_ermelo',
      name: 'DVS33 Ermelo',
      displayName: 'DVS’33 Ermelo',
      division: divisionA,
      logoFileName: 'logo_DVS33Ermelo.png',
      aliases: ['DVS33', 'DVS 33', 'DVS’33', 'DVS\'33'],
    ),
    SeasonTeam(
      id: 'evv_echt',
      name: 'EVV Echt',
      division: divisionA,
      logoFileName: 'logo_EVVEcht.png',
      aliases: ['EVV', 'EVV Echt-Susteren'],
    ),
    SeasonTeam(
      id: 'excelsior31',
      name: 'Excelsior31',
      displayName: 'Excelsior’31',
      division: divisionA,
      logoFileName: 'logo_Excelsior31.png',
      aliases: [
        'Excelsior 31',
        'Excelsior’31',
        'Excelsior\'31',
        'Excelsior Rijssen',
      ],
    ),
    SeasonTeam(
      id: 'excelsior_maassluis',
      name: 'Excelsior Maassluis',
      division: divisionA,
      logoFileName: 'logo_ExcelsiorMaassluis.png',
      aliases: ['Excelsior M'],
    ),
    SeasonTeam(
      id: 'fc_lisse',
      name: 'FC Lisse',
      division: divisionA,
      logoFileName: 'logo_FCLisse.png',
      aliases: ['Lisse'],
    ),
    SeasonTeam(
      id: 'fc_rijnvogels',
      name: 'FC Rijnvogels',
      division: divisionA,
      logoFileName: 'logo_FCRijnvogels.png',
      aliases: ['Rijnvogels', 'Rijnvogels Katwijk'],
    ),
    SeasonTeam(
      id: 'harkemase_boys',
      name: 'Harkemase Boys',
      division: divisionA,
      logoFileName: 'logo_HarkemaseBoys.png',
    ),
    SeasonTeam(
      id: 'hvv_hollandia',
      name: 'HVV Hollandia',
      division: divisionA,
      logoFileName: 'logo_HVVHollandia.png',
      aliases: ['Hollandia'],
    ),
    SeasonTeam(
      id: 'vpv_purmersteijn',
      name: 'VPV Purmersteijn',
      division: divisionA,
      logoFileName: 'logo_VPVPurmersteijn.png',
      aliases: ['Purmersteijn'],
    ),
    SeasonTeam(
      id: 'rbc',
      name: 'RBC',
      division: divisionA,
      logoFileName: 'logo_RBC.png',
      aliases: ['RBC Roosendaal'],
    ),
    SeasonTeam(
      id: 'rksv_groene_ster',
      name: 'RKSV Groene Ster',
      division: divisionA,
      logoFileName: 'logo_RKSVGroeneSter.png',
      aliases: ['Groene Ster', 'Groene Ster Heerlen'],
    ),
    SeasonTeam(
      id: 'sc_genemuiden',
      name: 'SC Genemuiden',
      division: divisionA,
      logoFileName: 'logo_SCGenemuiden.png',
      aliases: ['Genemuiden'],
    ),
    SeasonTeam(
      id: 'sportlust46',
      name: 'Sportlust46',
      displayName: 'Sportlust’46',
      division: divisionA,
      logoFileName: 'logo_Sportlust46.png',
      aliases: [
        'Sportlust 46',
        'Sportlust’46',
        'Sportlust\'46',
        'Sportlust ’46',
      ],
    ),
    SeasonTeam(
      id: 'sv_poortugaal',
      name: 'SV Poortugaal',
      division: divisionA,
      logoFileName: 'logo_SVPoortugaal.png',
      aliases: ['Poortugaal'],
    ),
    SeasonTeam(
      id: 'sv_tec',
      name: 'SV TEC',
      division: divisionA,
      logoFileName: 'logo_SVTEC.png',
      aliases: ['TEC', 's.v. TEC'],
    ),

    SeasonTeam(
      id: 'svzw',
      name: 'SVZW',
      division: divisionB,
      logoFileName: 'logo_SVZW.png',
      aliases: ['SVZW Wierden'],
    ),
    SeasonTeam(
      id: 'togb',
      name: 'TOGB',
      division: divisionB,
      logoFileName: 'logo_TOGB.png',
      aliases: ['TOGB Berkel'],
    ),
    SeasonTeam(
      id: 'udi19',
      name: 'UDI19',
      displayName: 'UDI’19',
      division: divisionB,
      logoFileName: 'logo_UDI19.png',
      aliases: [
        'UDI 19',
        'UDI’19',
        'UDI\'19',
        'UDI19/Swiss Sense',
        'UDI’19/Swiss Sense',
      ],
    ),
    SeasonTeam(
      id: 'usv_hercules',
      name: 'USV Hercules',
      division: divisionB,
      logoFileName: 'logo_USVHercules.png',
      aliases: ['Hercules'],
    ),
    SeasonTeam(
      id: 'vv_achilles_veen',
      name: 'VV Achilles Veen',
      division: divisionB,
      logoFileName: 'logo_VVAchillesVeen.png',
      aliases: ['Achilles Veen'],
    ),
    SeasonTeam(
      id: 'vv_dongen',
      name: 'VV Dongen',
      division: divisionB,
      logoFileName: 'logo_VVDongen.png',
      aliases: ['Dongen'],
    ),
    SeasonTeam(
      id: 'vv_dovo',
      name: 'VV DOVO',
      division: divisionB,
      logoFileName: 'logo_VVDOVO.png',
      aliases: ['DOVO'],
    ),
    SeasonTeam(
      id: 'vv_eemdijk',
      name: 'VV Eemdijk',
      division: divisionB,
      logoFileName: 'logo_VVEemdijk.png',
      aliases: ['Eemdijk', 'v.v. Eemdijk'],
    ),
    SeasonTeam(
      id: 'vv_gemert',
      name: 'VV Gemert',
      division: divisionB,
      logoFileName: 'logo_VVGemert.png',
      aliases: ['Gemert'],
    ),
    SeasonTeam(
      id: 'vv_goes',
      name: 'GOES',
      displayName: 'GOES',
      division: divisionB,
      logoFileName: 'logo_GOES.png',
      aliases: ['VV GOES', 'VV Goes', 'Goes'],
    ),
    SeasonTeam(
      id: 'vv_hoogeveen',
      name: 'VV Hoogeveen',
      division: divisionB,
      logoFileName: 'logo_VVHoogeveen.png',
      aliases: ['Hoogeveen', 'v.v. Hoogeveen'],
    ),
    SeasonTeam(
      id: 'vv_noordwijk',
      name: 'VV Noordwijk',
      division: divisionB,
      logoFileName: 'logo_VVNoordwijk.png',
      aliases: ['Noordwijk'],
    ),
    SeasonTeam(
      id: 'vv_scherpenzeel',
      name: 'VV Scherpenzeel',
      division: divisionB,
      logoFileName: 'logo_VVScherpenzeel.png',
      aliases: ['Scherpenzeel', 'v.v. Scherpenzeel'],
    ),
    SeasonTeam(
      id: 'vv_sparta_nijkerk',
      name: 'VV Sparta Nijkerk',
      division: divisionB,
      logoFileName: 'logo_VVSpartaNijkerk.png',
      aliases: ['Sparta Nijkerk'],
    ),
    SeasonTeam(
      id: 'vv_staphorst',
      name: 'VV Staphorst',
      division: divisionB,
      logoFileName: 'logo_VVStaphorst.png',
      aliases: ['Staphorst', 'v.v. Staphorst'],
    ),
    SeasonTeam(
      id: 'vv_una',
      name: 'VV UNA',
      division: divisionB,
      logoFileName: 'logo_VVUNA.png',
      aliases: ['UNA', 'UNA Veldhoven'],
    ),
    SeasonTeam(
      id: 'vv_zwaluwen',
      name: 'VV Zwaluwen',
      division: divisionB,
      logoFileName: 'logo_VVZwaluwen.png',
      aliases: ['Zwaluwen', 'Zwaluwen Vlaardingen'],
    ),
    SeasonTeam(
      id: 'vvsb',
      name: 'VVSB',
      division: divisionB,
      logoFileName: 'logo_VVSB.png',
      aliases: ['VVSB Noordwijkerhout'],
    ),
  ];

  static List<SeasonTeam> teamsForDivision(String division) {
    final normalizedDivision = normalizeDivisionCode(division);

    final result = teams
        .where((team) => team.division == normalizedDivision)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return List.unmodifiable(result);
  }

  static List<SeasonTeam> get teamsDivisionA {
    return teamsForDivision(divisionA);
  }

  static List<SeasonTeam> get teamsDivisionB {
    return teamsForDivision(divisionB);
  }

  static List<String> teamNamesForDivision(String division) {
    return teamsForDivision(division).map((team) => team.label).toList();
  }

  static SeasonTeam? teamById(String id) {
    final normalizedId = normalizeTeamKey(id);

    for (final team in teams) {
      if (normalizeTeamKey(team.id) == normalizedId) {
        return team;
      }
    }

    return null;
  }

  static SeasonTeam? teamByName(String value) {
    for (final team in teams) {
      if (team.matches(value)) {
        return team;
      }
    }

    return null;
  }

  static String displayNameForTeam(String value) {
    return teamByName(value)?.label ?? value;
  }

  static String logoPathForTeam(String value) {
    return teamByName(value)?.logoPath ?? 'assets/images/default_logo.png';
  }

  static String teamIdForName(String value) {
    return teamByName(value)?.id ?? normalizeTeamId(value);
  }

  static String divisionName(String division) {
    final normalizedDivision = normalizeDivisionCode(division);

    if (normalizedDivision == divisionA) {
      return divisionAName;
    }

    if (normalizedDivision == divisionB) {
      return divisionBName;
    }

    return division;
  }

  static String normalizeDivisionCode(String value) {
    final normalized = value.trim().toLowerCase();

    if (normalized == 'a' ||
        normalized == 'dda' ||
        normalized == 'divisie a' ||
        normalized == 'derde divisie a') {
      return divisionA;
    }

    if (normalized == 'b' ||
        normalized == 'ddb' ||
        normalized == 'divisie b' ||
        normalized == 'derde divisie b') {
      return divisionB;
    }

    return value.trim().toUpperCase();
  }

  static String firestoreDivisionCode(String division) {
    final normalizedDivision = normalizeDivisionCode(division);

    if (normalizedDivision == divisionA) {
      return 'dda';
    }

    if (normalizedDivision == divisionB) {
      return 'ddb';
    }

    return division.trim().toLowerCase();
  }

  static String normalizeTeamKey(String value) {
    return value
        .toUpperCase()
        .replaceAll('’', '')
        .replaceAll("'", '')
        .replaceAll('`', '')
        .replaceAll('´', '')
        .replaceAll(' ', '')
        .replaceAll('/', '')
        .replaceAll('.', '')
        .replaceAll('-', '')
        .replaceAll('_', '')
        .replaceAll('&', 'EN')
        .trim();
  }

  static String normalizeTeamId(String value) {
    return value
        .toLowerCase()
        .replaceAll('’', '')
        .replaceAll("'", '')
        .replaceAll('`', '')
        .replaceAll('´', '')
        .replaceAll('&', 'en')
        .replaceAll('/', '_')
        .replaceAll('.', '')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}