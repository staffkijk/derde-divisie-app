param(
  [switch]$SkipFirebase,
  [switch]$SkipWebBuild
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root

function Step($message) {
  Write-Host "`n=== $message ===" -ForegroundColor Cyan
}

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Vereist commando ontbreekt: $name"
  }
}

Require-Command flutter
Require-Command node
Require-Command npm
Require-Command npx

Step 'Flutter dependencies'
flutter pub get

Step 'Flutter unit- en widgettests'
flutter test

Step 'Volledig seizoen: 612 wedstrijden'
flutter test test/features/full_season_regression_test.dart -r expanded

Step 'Web update regressie'
npm run test:web-update

Step 'Firestore security rules'
npm run test:security

Step 'Cloud Functions tests'
npm --prefix functions test

if (-not $SkipWebBuild) {
  Step 'Web release-build compileren'
  flutter build web
}

if (-not $SkipFirebase) {
  Step 'Firebase ketentest: uitslag, stand, periodestand en deelnemerspunten'

  $devices = flutter devices
  $target = if ($devices -match 'Windows \(desktop\)') { 'windows' } elseif ($devices -match 'macOS \(desktop\)') { 'macos' } elseif ($devices -match 'Linux \(desktop\)') { 'linux' } else { $null }
  if (-not $target) {
    throw 'Geen desktop Flutter target gevonden voor de Firebase integration test.'
  }

  $inner = "node tools/regression/seed_emulator.cjs && flutter test integration_test/firebase_result_processing_test.dart -d $target"
  npx firebase emulators:exec --project derde-divisie-app --only auth,firestore $inner
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host 'DERDEDIV REGRESSIE: ALLE UITGEVOERDE TESTS GESLAAGD' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Green
