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

  String get assetCode {
    return logoFileName
        .replaceFirst('logo_', '')
        .replaceFirst(RegExp(r'\.(png|webp|jpg|jpeg)$'), '');
  }

  String get listLabel {
    switch (id) {
      case 'ado20':
        return "ADO '20";
      case 'blauw_geel_38':
        return "Blauw Geel'38/Jumbo";
      case 'dvs33_ermelo':
        return "DVS'33 Ermelo";
      case 'excelsior31':
        return "Excelsior'31";
      case 'fc_rijnvogels':
        return 'Rijnvogels';
      case 'hvv_hollandia':
        return 'Hollandia';
      case 'rksv_groene_ster':
        return 'Groene Ster';
      case 'sportlust46':
        return "Sportlust'46";
      case 'sv_poortugaal':
        return 'sv Poortugaal';
      case 'sv_tec':
        return 'TEC';
      case 'udi19':
        return "UDI'19";
      case 'usv_hercules':
        return 'Hercules';
      case 'vpv_purmersteijn':
        return 'Purmersteijn';
      case 'vv_achilles_veen':
        return 'Achilles Veen';
      case 'vv_dongen':
        return 'Dongen';
      case 'vv_dovo':
        return 'DOVO';
      case 'vv_eemdijk':
        return 'Eemdijk';
      case 'vv_gemert':
        return 'Gemert';
      case 'vv_goes':
        return 'Goes';
      case 'vv_hoogeveen':
        return 'Hoogeveen';
      case 'vv_noordwijk':
        return 'Noordwijk';
      case 'vv_scherpenzeel':
        return 'Scherpenzeel';
      case 'vv_sparta_nijkerk':
        return 'Sparta Nijkerk';
      case 'vv_staphorst':
        return 'Staphorst';
      case 'vv_una':
        return 'UNA';
      case 'vv_zwaluwen':
        return 'Zwaluwen';
      default:
        return label;
    }
  }

  bool matches(String value) {
    final input = SeasonConfig.normalizeTeamKey(value);

    if (input == SeasonConfig.normalizeTeamKey(id)) return true;
    if (input == SeasonConfig.normalizeTeamKey(name)) return true;
    if (input == SeasonConfig.normalizeTeamKey(label)) return true;
    if (input == SeasonConfig.normalizeTeamKey(listLabel)) return true;
    if (input == SeasonConfig.normalizeTeamKey(assetCode)) return true;

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

  /// De definitieve A/B-indeling voor 2026/2027 is verwerkt.
  static const bool useProvisionalDivisionSplit = false;

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
      division: divisionB,
      logoFileName: 'logo_BlauwGeel38JUMBO.png',
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
      division: divisionB,
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
      division: divisionB,
      logoFileName: 'logo_ExcelsiorMaassluis.png',
      aliases: ['Excelsior M'],
    ),
    SeasonTeam(
      id: 'fc_lisse',
      name: 'FC Lisse',
      division: divisionB,
      logoFileName: 'logo_FCLisse.png',
      aliases: ['Lisse'],
    ),
    SeasonTeam(
      id: 'fc_rijnvogels',
      name: 'FC Rijnvogels',
      division: divisionB,
      logoFileName: 'logo_Rijnvogels.png',
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
      logoFileName: 'logo_Hollandia.png',
      aliases: ['Hollandia'],
    ),
    SeasonTeam(
      id: 'vpv_purmersteijn',
      name: 'VPV Purmersteijn',
      division: divisionA,
      logoFileName: 'logo_Purmersteijn.png',
      aliases: ['Purmersteijn'],
    ),
    SeasonTeam(
      id: 'rbc',
      name: 'RBC',
      division: divisionB,
      logoFileName: 'logo_RBC.png',
      aliases: ['RBC Roosendaal'],
    ),
    SeasonTeam(
      id: 'rksv_groene_ster',
      name: 'RKSV Groene Ster',
      division: divisionB,
      logoFileName: 'logo_GroeneSter.png',
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
      division: divisionB,
      logoFileName: 'logo_Poortugaal.png',
      aliases: ['Poortugaal'],
    ),
    SeasonTeam(
      id: 'sv_tec',
      name: 'SV TEC',
      division: divisionA,
      logoFileName: 'logo_TEC.png',
      aliases: ['TEC', 's.v. TEC'],
    ),
    SeasonTeam(
      id: 'svzw',
      name: 'SVZW',
      division: divisionA,
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
      division: divisionA,
      logoFileName: 'logo_Hercules.png',
      aliases: ['Hercules'],
    ),
    SeasonTeam(
      id: 'vv_achilles_veen',
      name: 'VV Achilles Veen',
      division: divisionB,
      logoFileName: 'logo_AchillesVeen.png',
      aliases: ['Achilles Veen'],
    ),
    SeasonTeam(
      id: 'vv_dongen',
      name: 'VV Dongen',
      division: divisionB,
      logoFileName: 'logo_dongen.png',
      aliases: ['Dongen'],
    ),
    SeasonTeam(
      id: 'vv_dovo',
      name: 'VV DOVO',
      division: divisionA,
      logoFileName: 'logo_DOVO.png',
      aliases: ['DOVO'],
    ),
    SeasonTeam(
      id: 'vv_eemdijk',
      name: 'VV Eemdijk',
      division: divisionA,
      logoFileName: 'logo_Eemdijk.png',
      aliases: ['Eemdijk', 'v.v. Eemdijk'],
    ),
    SeasonTeam(
      id: 'vv_gemert',
      name: 'VV Gemert',
      division: divisionB,
      logoFileName: 'logo_Gemert.png',
      aliases: ['Gemert'],
    ),
    SeasonTeam(
      id: 'vv_goes',
      name: 'GOES',
      displayName: 'GOES',
      division: divisionB,
      logoFileName: 'logo_Goes.png',
      aliases: ['VV GOES', 'VV Goes', 'Goes'],
    ),
    SeasonTeam(
      id: 'vv_hoogeveen',
      name: 'VV Hoogeveen',
      division: divisionA,
      logoFileName: 'logo_Hoogeveen.png',
      aliases: ['Hoogeveen', 'v.v. Hoogeveen'],
    ),
    SeasonTeam(
      id: 'vv_noordwijk',
      name: 'VV Noordwijk',
      division: divisionB,
      logoFileName: 'logo_Noordwijk.png',
      aliases: ['Noordwijk'],
    ),
    SeasonTeam(
      id: 'vv_scherpenzeel',
      name: 'VV Scherpenzeel',
      division: divisionA,
      logoFileName: 'logo_Scherpenzeel.png',
      aliases: ['Scherpenzeel', 'v.v. Scherpenzeel'],
    ),
    SeasonTeam(
      id: 'vv_sparta_nijkerk',
      name: 'VV Sparta Nijkerk',
      division: divisionA,
      logoFileName: 'logo_SpartaNijkerk.png',
      aliases: ['Sparta Nijkerk'],
    ),
    SeasonTeam(
      id: 'vv_staphorst',
      name: 'VV Staphorst',
      division: divisionA,
      logoFileName: 'logo_Staphorst.png',
      aliases: ['Staphorst', 'v.v. Staphorst'],
    ),
    SeasonTeam(
      id: 'vv_una',
      name: 'VV UNA',
      division: divisionB,
      logoFileName: 'logo_UNA.png',
      aliases: ['UNA', 'UNA Veldhoven'],
    ),
    SeasonTeam(
      id: 'vv_zwaluwen',
      name: 'VV Zwaluwen',
      division: divisionB,
      logoFileName: 'logo_Zwaluwen.png',
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

  static List<SeasonTeam> get teamsInListOrder {
    return List.unmodifiable(teams);
  }

  static List<SeasonTeam> teamsForProvisionalStandDivision(String division) {
    if (!useProvisionalDivisionSplit) {
      return teamsForDivision(division);
    }
    final sorted = List<SeasonTeam>.from(teams)
      ..sort(
        (a, b) =>
            a.listLabel.toLowerCase().compareTo(b.listLabel.toLowerCase()),
      );

    final normalizedDivision = normalizeDivisionCode(division);
    final result = normalizedDivision == divisionA
        ? sorted.take(18).toList()
        : sorted.skip(18).toList();

    return List.unmodifiable(result);
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
    return logoPathForTeamOrNull(value) ?? defaultTeamLogoPath;
  }

  static String? logoPathForTeamOrNull(String value) {
    final team = teamByName(value);
    if (team != null) return team.logoPath;

    return logoMapByTeamCode[normalizeTeamKey(value)];
  }

  static String teamIdForName(String value) {
    return teamByName(value)?.id ?? normalizeTeamId(value);
  }

  static String teamCodeForName(String value) {
    final team = teamByName(value);
    if (team != null) return team.assetCode;

    final normalized = normalizeTeamKey(value);
    return _legacyTeamCodeMapping[normalized] ?? normalizeTeamId(value);
  }

  static String divisionCodeForTeam(String value) {
    final team = teamByName(value);
    if (team != null) return firestoreDivisionCode(team.division);

    final normalized = normalizeTeamKey(teamCodeForName(value));
    return _legacyTeamDivisionMapping[normalized] ?? 'onbekend';
  }

  static Map<String, String> get teamCodeMapping {
    final result = <String, String>{};

    for (final team in teams) {
      result[team.name] = team.assetCode;
      result[team.label] = team.assetCode;
      result[team.listLabel] = team.assetCode;
      result[team.id] = team.assetCode;
      result[team.assetCode] = team.assetCode;
      for (final alias in team.aliases) {
        result[alias] = team.assetCode;
      }
    }

    result.addAll({
      for (final entry in _legacyTeamCodeMapping.entries)
        entry.key: entry.value,
    });
    result.addAll({
      for (final entry in _legacyCodeToTeamName.entries) entry.key: entry.key,
      for (final entry in _legacyCodeToTeamName.entries) entry.value: entry.key,
      'AD020': 'ADO20',
      'Blauw Geel\'38/JUMBO': 'BlauwGeel38JUMBO',
      'Blauw Geelâ€™38/JUMBO': 'BlauwGeel38JUMBO',
      'Blauw Geel 38 JUMBO': 'BlauwGeel38JUMBO',
    });

    return Map.unmodifiable(result);
  }

  static Map<String, String> get codeToTeamName {
    final result = <String, String>{};

    for (final team in teams) {
      result[team.assetCode] = team.listLabel;
    }

    result.addAll(_legacyCodeToTeamName);
    return Map.unmodifiable(result);
  }

  static Map<String, String> get logoMapByTeamCode {
    final result = <String, String>{};

    for (final team in teams) {
      result[normalizeTeamKey(team.assetCode)] = team.logoPath;
      result[team.assetCode] = team.logoPath;
      result[normalizeTeamKey(team.name)] = team.logoPath;
      result[normalizeTeamKey(team.label)] = team.logoPath;
      result[normalizeTeamKey(team.listLabel)] = team.logoPath;
      for (final alias in team.aliases) {
        result[normalizeTeamKey(alias)] = team.logoPath;
      }
    }

    for (final entry in _legacyLogoMapByTeamCode.entries) {
      result.putIfAbsent(normalizeTeamKey(entry.key), () => entry.value);
      result.putIfAbsent(entry.key, () => entry.value);
    }

    return Map.unmodifiable(result);
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

  static const String defaultTeamLogoPath = 'assets/images/default_logo.png';

  static const Map<String, String> _legacyCodeToTeamName = {
    'ASWH': 'ASWH',
    'HSC21': 'HSC\'21',
    'Huizen': 'Huizen',
    'Kloetinge': 'Kloetinge',
    'RohdaRaalte': 'Rohda Raalte',
    'Scheveningen': 'Scheveningen',
    'SteDoCo': 'SteDoCo',
    'Urk': 'Urk',
    'svMeerssen': 'sv Meerssen',
  };

  static final Map<String, String> _legacyTeamCodeMapping = {
    for (final entry in _legacyCodeToTeamName.entries)
      normalizeTeamKey(entry.key): entry.key,
    for (final entry in _legacyCodeToTeamName.entries)
      normalizeTeamKey(entry.value): entry.key,
    normalizeTeamKey('AD020'): 'ADO20',
    normalizeTeamKey('Blauw Geel\'38/JUMBO'): 'BlauwGeel38JUMBO',
    normalizeTeamKey('Blauw Geelâ€™38/JUMBO'): 'BlauwGeel38JUMBO',
    normalizeTeamKey('Blauw Geel 38 JUMBO'): 'BlauwGeel38JUMBO',
  };

  static const Map<String, String> _legacyLogoMapByTeamCode = {
    'ASWH': 'assets/images/logo_ASWH.png',
    'HSC21': 'assets/images/logo_HSC21.png',
    'Huizen': 'assets/images/logo_Huizen.png',
    'Kloetinge': 'assets/images/logo_Kloetinge.png',
    'RohdaRaalte': 'assets/images/logo_RohdaRaalte.png',
    'Scheveningen': 'assets/images/logo_Scheveningen.png',
    'SteDoCo': 'assets/images/logo_SteDoCo.png',
    'Urk': 'assets/images/logo_Urk.png',
    'svMeerssen': 'assets/images/logo_svMeerssen.png',
  };

  static final Map<String, String> _legacyTeamDivisionMapping = {
    for (final code in _legacyDdaTeamCodes) normalizeTeamKey(code): 'dda',
    for (final code in _legacyDdbTeamCodes) normalizeTeamKey(code): 'ddb',
  };

  static const List<String> _legacyDdaTeamCodes = [
    'DOVO',
    'Eemdijk',
    'Scherpenzeel',
    'Staphorst',
    'DVS33Ermelo',
    'SpartaNijkerk',
    'TEC',
    'Urk',
    'Hoogeveen',
    'HSC21',
    'Sportlust46',
    'Excelsior31',
    'Hercules',
    'SCGenemuiden',
    'Huizen',
    'HarkemaseBoys',
    'RohdaRaalte',
    'ADO20',
  ];

  static const List<String> _legacyDdbTeamCodes = [
    'Noordwijk',
    'Scheveningen',
    'SteDoCo',
    'Zwaluwen',
    'Kloetinge',
    'RBC',
    'GroeneSter',
    'Rijnvogels',
    'UNA',
    'ASWH',
    'UDI19',
    'TOGB',
    'FCLisse',
    'Gemert',
    'svMeerssen',
    'BlauwGeel38JUMBO',
    'Goes',
    'VVSB',
  ];
}
