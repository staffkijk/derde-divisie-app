int berekenPunten({
  required int voorspeldThuis,
  required int voorspeldUit,
  required int echtThuis,
  required int echtUit,
}) {
  // Exacte score goed (10 punten)
  if (voorspeldThuis == echtThuis && voorspeldUit == echtUit) {
    return 10;
  }

  // Gelijkspel correct voorspeld, maar niet exact (7 punten)
  bool voorspeldGelijkspel = voorspeldThuis == voorspeldUit;
  bool echtGelijkspel = echtThuis == echtUit;
  if (voorspeldGelijkspel && echtGelijkspel && (voorspeldThuis != echtThuis || voorspeldUit != echtUit)) {
    return 7;
  }

  // Winnaar correct voorspeld (5 punten)
  bool voorspeldThuisWint = voorspeldThuis > voorspeldUit;
  bool echtThuisWint = echtThuis > echtUit;
  bool voorspeldUitWint = voorspeldUit > voorspeldThuis;
  bool echtUitWint = echtUit > echtThuis;
  if ((voorspeldThuisWint && echtThuisWint) || (voorspeldUitWint && echtUitWint)) {
    return 5;
  }

  // Punten voor correct aantal doelpunten per team (2 punten per team)
  int punten = 0;
  if (voorspeldThuis == echtThuis) punten += 2;
  if (voorspeldUit == echtUit) punten += 2;

  return punten;
}
