// lib/utils/app_reloader_impl_stub.dart

/// Interface die door web- en stub-implementaties wordt gebruikt.
abstract class AppReloaderImpl {
  Future<void> hardReload();
}

/// Non-web (of unsupported) implementatie: doet niets.
class _NoopReloader implements AppReloaderImpl {
  @override
  Future<void> hardReload() async {
    // no-op
  }
}

/// Factory die door de conditional import wordt opgepakt.
AppReloaderImpl getAppReloader() => _NoopReloader();
