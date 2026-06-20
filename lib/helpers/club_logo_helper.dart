import 'package:flutter/material.dart';

final Map<String, String> clubLogoMap = {
  'ADO20': 'assets/images/logo_ADO20.png',
  'ASWH': 'assets/images/logo_ASWH.png',
  'BlauwGeel138JUMBO': 'assets/images/logo_BlauwGeel138JUMBO.png',
  'DOVO': 'assets/images/logo_DOVO.png',
  'DVS33Ermelo': 'assets/images/logo_DVS33Ermelo.png',
  'Eemdijk': 'assets/images/logo_Eemdijk.png',
  'Excelsior31': 'assets/images/logo_Excelsior31.png',
  'FCLisse': 'assets/images/logo_FCLisse.png',
  'Gemert': 'assets/images/logo_Gemert.png',
  'Goes': 'assets/images/logo_Goes.png',
  'GroeneSter': 'assets/images/logo_GroeneSter.png',
  'HSC21': 'assets/images/logo_HSC21.png',
  'HarkemaseBoys': 'assets/images/logo_HarkemaseBoys.png',
  'Hercules': 'assets/images/logo_Hercules.png',
  'Hoogeveen': 'assets/images/logo_Hoogeveen.png',
  'Huizen': 'assets/images/logo_Huizen.png',
  'Kloetinge': 'assets/images/logo_Kloetinge.png',
  'Noordwijk': 'assets/images/logo_Noordwijk.png',
  'RBC': 'assets/images/logo_RBC.png',
  'Rijnvogels': 'assets/images/logo_Rijnvogels.png',
  'RohdaRaalte': 'assets/images/logo_RohdaRaalte.png',
  'SCGenemuiden': 'assets/images/logo_SCGenemuiden.png',
  'Scherpenzeel': 'assets/images/logo_Scherpenzeel.png',
  'Scheveningen': 'assets/images/logo_Scheveningen.png',
  'SpartaNijkerk': 'assets/images/logo_SpartaNijkerk.png',
  'Sportlust46': 'assets/images/logo_Sportlust46.png',
  'Staphorst': 'assets/images/logo_Staphorst.png',
  'SteDoCo': 'assets/images/logo_SteDoCo.png',
  'TEC': 'assets/images/logo_TEC.png',
  'TOGB': 'assets/images/logo_TOGB.png',
  'UDI19': 'assets/images/logo_UDI19.png',
  'UNA': 'assets/images/logo_UNA.png',
  'Urk': 'assets/images/logo_Urk.png',
  'VVSB': 'assets/images/logo_VVSB.png',
  'Zwaluwen': 'assets/images/logo_Zwaluwen.png',
  'svMeerssen': 'assets/images/logo_svMeerssen.png',
};

Widget getLogo(String clubnaam, {double size = 24}) {
  final String? imagePath = clubLogoMap[clubnaam];
  if (imagePath != null) {
    return Image.asset(
      imagePath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  } else {
    return Icon(Icons.sports_soccer, size: size);
  }
}
