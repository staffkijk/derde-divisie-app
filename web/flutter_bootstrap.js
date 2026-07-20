{{flutter_js}}
{{flutter_build_config}}

// Start zonder Flutter app-shell-service-worker. De DerdeDiv-updater haalt eerst
// de actuele release op en geeft main.dart.js een versiespecifieke URL.
DerdeDivUpdater.createUpdater().startAndLoad(_flutter);
