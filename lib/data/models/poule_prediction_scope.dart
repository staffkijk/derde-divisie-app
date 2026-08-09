enum PoulePredictionScope {
  matches,
  finalRanking,
  both,
}

PoulePredictionScope parsePoulePredictionScope(dynamic value) {
  switch (value?.toString()) {
    case 'finalRanking':
      return PoulePredictionScope.finalRanking;
    case 'both':
      return PoulePredictionScope.both;
    case 'matches':
    default:
      return PoulePredictionScope.matches;
  }
}

extension PoulePredictionScopePresentation on PoulePredictionScope {
  String get firestoreValue {
    switch (this) {
      case PoulePredictionScope.matches:
        return 'matches';
      case PoulePredictionScope.finalRanking:
        return 'finalRanking';
      case PoulePredictionScope.both:
        return 'both';
    }
  }

  String get label {
    switch (this) {
      case PoulePredictionScope.matches:
        return 'Wedstrijduitslagen';
      case PoulePredictionScope.finalRanking:
        return 'Eindstandranking';
      case PoulePredictionScope.both:
        return 'Wedstrijden en eindstand';
    }
  }

  String get explanation {
    switch (this) {
      case PoulePredictionScope.matches:
        return 'Alleen punten uit voorspelde wedstrijduitslagen tellen mee.';
      case PoulePredictionScope.finalRanking:
        return 'Alleen de voorspelde eindstand van de relevante divisie telt mee.';
      case PoulePredictionScope.both:
        return 'Wedstrijdpunten en eindstandpunten worden gecombineerd.';
    }
  }
}
