/// Naam → Code
const Map<String, String> teamCodeMapping = {
  'ADO\'20': 'ADO20',
  'ADO’20': 'ADO20', // curly apostrof
  'ADO20': 'ADO20', // zonder apostrof
  'AD020': 'ADO20', // typevariant

  'ASWH': 'ASWH',

  'Blauw Geel\'38/JUMBO': 'BlauwGeel38JUMBO',
  'Blauw Geel’38/JUMBO': 'BlauwGeel38JUMBO',
  'Blauw Geel 38 JUMBO': 'BlauwGeel38JUMBO',

  'DOVO': 'DOVO',

  'DVS33 Ermelo': 'DVS33Ermelo',

  'Eemdijk': 'Eemdijk',

  'Excelsior\'31': 'Excelsior31',
  'Excelsior’31': 'Excelsior31',
  'Excelsior 31': 'Excelsior31',

  'FC Lisse': 'FCLisse',

  'Gemert': 'Gemert',

  'Goes': 'Goes',

  'Groene Ster': 'GroeneSter',

  'Harkemase Boys': 'HarkemaseBoys',

  'Hercules': 'Hercules',

  'Hoogeveen': 'Hoogeveen',

  'HSC\'21': 'HSC21',
  'HSC’21': 'HSC21',
  'HSC 21': 'HSC21',

  'Huizen': 'Huizen',

  'Kloetinge': 'Kloetinge',

  'Noordwijk': 'Noordwijk',

  'RBC': 'RBC',

  'Rijnvogels': 'Rijnvogels',

  'Rohda Raalte': 'RohdaRaalte',

  'SC Genemuiden': 'SCGenemuiden',

  'Scherpenzeel': 'Scherpenzeel',

  'Scheveningen': 'Scheveningen',

  'Sparta Nijkerk': 'SpartaNijkerk',

  'Sportlust \'46': 'Sportlust46',
  'Sportlust ’46': 'Sportlust46',
  'Sportlust 46': 'Sportlust46',

  'Staphorst': 'Staphorst',

  'SteDoCo': 'SteDoCo',

  'sv Meerssen': 'svMeerssen',

  'TEC': 'TEC',

  'TOGB': 'TOGB',

  'UDI\'19': 'UDI19',
  'UDI’19': 'UDI19',
  'UDI 19': 'UDI19',

  'UNA': 'UNA',

  'Urk': 'Urk',

  'VVSB': 'VVSB',

  'Zwaluwen': 'Zwaluwen',
};

/// Code → Naam (afgeleid uit bovenstaand map)
final Map<String, String> codeToTeamName = Map.unmodifiable({
  for (final entry in teamCodeMapping.entries) entry.value: entry.key,
});
