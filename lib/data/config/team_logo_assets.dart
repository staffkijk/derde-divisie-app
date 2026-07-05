String _normalizeTeamLogoKey(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

const String kDefaultTeamLogoAsset = 'assets/images/default_logo.png';

const Map<String, String> kTeamLogoAssets = {
  'achillesveen': 'assets/images/logo_AchillesVeen.png',
  'achilles29': 'assets/images/logo_Achilles29.png',
  'jongachilles29': 'assets/images/logo_Achilles29.png',
  'acv': 'assets/images/logo_ACV.png',
  'ado20': 'assets/images/logo_ADO20.png',
  'ajaxamateurs': 'assets/images/logo_AjaxAmateurs.png',
  'ajaxam': 'assets/images/logo_AjaxAmateurs.png',
  'asvdedijk': 'assets/images/logo_ASVDeDijk.png',
  'aswh': 'assets/images/logo_ASWH.png',
  'awc': 'assets/images/logo_AWC.png',
  'barendrecht': 'assets/images/logo_Barendrecht.png',
  'bvvbarendrecht': 'assets/images/logo_Barendrecht.png',
  'baronie': 'assets/images/logo_Baronie.png',
  'vvbaronie': 'assets/images/logo_Baronie.png',
  'bequick1887': 'assets/images/logo_BeQuick1887.png',
  'blauwgeel38': 'assets/images/logo_BlauwGeel38JUMBO.png',
  'blauwgeel38jumbo': 'assets/images/logo_BlauwGeel38JUMBO.png',
  'capelle': 'assets/images/logo_Capelle.png',
  'vvcapelle': 'assets/images/logo_Capelle.png',
  'dem': 'assets/images/logo_DEM.png',
  'rkvvdem': 'assets/images/logo_DEM.png',
  'dongen': 'assets/images/logo_dongen.png',
  'vvdongen': 'assets/images/logo_dongen.png',
  'dovo': 'assets/images/logo_DOVO.png',
  'vvdovo': 'assets/images/logo_DOVO.png',
  'dvs33ermelo': 'assets/images/logo_DVS33Ermelo.png',
  'eemdijk': 'assets/images/logo_Eemdijk.png',
  'vveemdijk': 'assets/images/logo_Eemdijk.png',
  'evv': 'assets/images/logo_EVVEcht.png',
  'evvecht': 'assets/images/logo_EVVEcht.png',
  'excelsior31': 'assets/images/logo_Excelsior31.png',
  'excelsiormaassluis': 'assets/images/logo_ExcelsiorMaassluis.png',
  'fclisse': 'assets/images/logo_FCLisse.png',
  'fclienden': 'assets/images/logo_FCLienden.png',
  'fcrijnvogels': 'assets/images/logo_Rijnvogels.png',
  'rijnvogels': 'assets/images/logo_Rijnvogels.png',
  'gemert': 'assets/images/logo_Gemert.png',
  'vvgemert': 'assets/images/logo_Gemert.png',
  'genemuiden': 'assets/images/logo_SCGenemuiden.png',
  'scgenemuiden': 'assets/images/logo_SCGenemuiden.png',
  'goes': 'assets/images/logo_Goes.png',
  'vvgoes': 'assets/images/logo_Goes.png',
  'groenester': 'assets/images/logo_GroeneSter.png',
  'rksvgroenester': 'assets/images/logo_GroeneSter.png',
  'gvvv': 'assets/images/logo_GVVV.png',
  'gvvunitas': 'assets/images/logo_GVVUnitas.png',
  'harkemaseboys': 'assets/images/logo_HarkemaseBoys.png',
  'hbc': 'assets/images/logo_HBC.png',
  'hbs': 'assets/images/logo_HBS.png',
  'hbscraeyenhout': 'assets/images/logo_HBS.png',
  'hercules': 'assets/images/logo_Hercules.png',
  'usvhercules': 'assets/images/logo_Hercules.png',
  'hoek': 'assets/images/logo_Hoek.png',
  'hsvhoek': 'assets/images/logo_Hoek.png',
  'hollandia': 'assets/images/logo_Hollandia.png',
  'hvvhollandia': 'assets/images/logo_Hollandia.png',
  'hoogland': 'assets/images/logo_Hoogland.png',
  'vvhoogland': 'assets/images/logo_Hoogland.png',
  'hoogeveen': 'assets/images/logo_Hoogeveen.png',
  'vvhoogeveen': 'assets/images/logo_Hoogeveen.png',
  'hsc21': 'assets/images/logo_HSC21.png',
  'huizen': 'assets/images/logo_Huizen.png',
  'svhuizen': 'assets/images/logo_Huizen.png',
  'ijsselmeervogels': 'assets/images/logo_IJsselmeervogels.png',
  'vvijsselmeervogels': 'assets/images/logo_IJsselmeervogels.png',
  'jongadodenhaag': 'assets/images/logo_JongADODenHaag.png',
  'jongalmerecityfc': 'assets/images/logo_JongAlmereCityFC.png',
  'jongdegraafschap': 'assets/images/logo_JongDeGraafschap.png',
  'jongfcdenbosch': 'assets/images/logo_JongFCDenBosch.png',
  'jongfcgroningen': 'assets/images/logo_JongFCGroningen.png',
  'jongfctwente': 'assets/images/logo_JongFCTwente.png',
  'jongfcvolendam': 'assets/images/logo_JongFCVolendam.png',
  'jongvitesse': 'assets/images/logo_JongVitesse.png',
  'joswatergraafsmeer': 'assets/images/logo_JOSWatergraafsmeer.png',
  'jvccuijk': 'assets/images/logo_JVCCuijk.png',
  'kampong': 'assets/images/logo_Kampong.png',
  'kloetinge': 'assets/images/logo_Kloetinge.png',
  'kozakkenboys': 'assets/images/logo_KozakkenBoys.png',
  'magreb90': 'assets/images/logo_Magreb90.png',
  'meern': 'assets/images/logo_DeMeern.png',
  'vvdemeern': 'assets/images/logo_DeMeern.png',
  'noordwijk': 'assets/images/logo_Noordwijk.png',
  'vvnoordwijk': 'assets/images/logo_Noordwijk.png',
  'odin59': 'assets/images/logo_ODIN59.png',
  'ofc': 'assets/images/logo_OFC.png',
  'ojcrosmalen': 'assets/images/logo_OJCRosmalen.png',
  'onssneek': 'assets/images/logo_ONSSneek.png',
  'oss20': 'assets/images/logo_OSS20.png',
  'svoss20': 'assets/images/logo_OSS20.png',
  'poortugaal': 'assets/images/logo_Poortugaal.png',
  'svpoortugaal': 'assets/images/logo_Poortugaal.png',
  'purmersteijn': 'assets/images/logo_Purmersteijn.png',
  'vpvpurmersteijn': 'assets/images/logo_Purmersteijn.png',
  'quick': 'assets/images/logo_Quick.png',
  'quick20': 'assets/images/logo_Quick20.png',
  'quickboys': 'assets/images/logo_QuickBoys.png',
  'quickh': 'assets/images/logo_Quick.png',
  'rbc': 'assets/images/logo_RBC.png',
  'rijnsburgseboys': 'assets/images/logo_RijnsburgseBoys.png',
  'rkavvolendam': 'assets/images/logo_RKAVVolendam.png',
  'rkvvwestlandia': 'assets/images/logo_Westlandia.png',
  'rohdaraalte': 'assets/images/logo_RohdaRaalte.png',
  'scherpenzeel': 'assets/images/logo_Scherpenzeel.png',
  'vvscherpenzeel': 'assets/images/logo_Scherpenzeel.png',
  'scheveningen': 'assets/images/logo_Scheveningen.png',
  'svvscheveningen': 'assets/images/logo_Scheveningen.png',
  'sjc': 'assets/images/logo_SJC.png',
  'vvsjc': 'assets/images/logo_SJC.png',
  'sgravenzande': 'assets/images/logo_sGravenzande.png',
  'smitshoek': 'assets/images/logo_Smitshoek.png',
  'spakenburg': 'assets/images/logo_Spakenburg.png',
  'svspakenburg': 'assets/images/logo_Spakenburg.png',
  'spartanijkerk': 'assets/images/logo_SpartaNijkerk.png',
  'vvspartanijkerk': 'assets/images/logo_SpartaNijkerk.png',
  'spijkenisse': 'assets/images/logo_Spijkenisse.png',
  'vvspijkenisse': 'assets/images/logo_Spijkenisse.png',
  'sportlust': 'assets/images/logo_Sportlust46.png',
  'sportlust46': 'assets/images/logo_Sportlust46.png',
  'vvsportlust46': 'assets/images/logo_Sportlust46.png',
  'staphorst': 'assets/images/logo_Staphorst.png',
  'vvstaphorst': 'assets/images/logo_Staphorst.png',
  'stedoco': 'assets/images/logo_SteDoCo.png',
  'svjuliana31': 'assets/images/logo_Juliana31.png',
  'svmeersen': 'assets/images/logo_svMeerssen.png',
  'svmeerssen': 'assets/images/logo_svMeerssen.png',
  'svzw': 'assets/images/logo_SVZW.png',
  'tec': 'assets/images/logo_TEC.png',
  'svtec': 'assets/images/logo_TEC.png',
  'terleede': 'assets/images/logo_TerLeede.png',
  'togb': 'assets/images/logo_TOGB.png',
  'udi19': 'assets/images/logo_UDI19.png',
  'una': 'assets/images/logo_UNA.png',
  'vvuna': 'assets/images/logo_UNA.png',
  'urk': 'assets/images/logo_Urk.png',
  'svurk': 'assets/images/logo_Urk.png',
  'vitesse': 'assets/images/logo_JongVitesse.png',
  'vvog': 'assets/images/logo_VVOG.png',
  'vvogharderwijk': 'assets/images/logo_VVOG.png',
  'vvsb': 'assets/images/logo_VVSB.png',
  'westlandia': 'assets/images/logo_Westlandia.png',
  'zwaluwen': 'assets/images/logo_Zwaluwen.png',
};

String? teamLogoAssetForName(String name) {
  final key = _normalizeTeamLogoKey(name);
  return kTeamLogoAssets[key];
}

String? teamLogoAssetFromValues(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      continue;
    }

    if (text.startsWith('assets/images/')) {
      return text;
    }

    final mappedPath = teamLogoAssetForName(text);

    if (mappedPath != null) {
      return mappedPath;
    }
  }

  return null;
}
