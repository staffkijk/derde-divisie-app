export 'package:derde_divisie/Puntensysteem/puntenlogica.dart' show berekenPunten;
import 'package:derde_divisie/features/moderator/result_processing_service.dart';
Future<void> verwerkVoorspellingenVoorWedstrijd(String wedstrijdId,
    int echtThuis, int echtUit) => ResultProcessingService.requestProcessing(wedstrijdId);
