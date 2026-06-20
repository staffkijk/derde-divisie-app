// lib/utils/app_reloader_impl_web.dart
import 'package:web/web.dart' as web;
import 'app_reloader_impl_stub.dart' as base;

// ⬅️ directives (zoals export) moeten vóór class/func-declaraties staan
export 'app_reloader_impl_stub.dart' show AppReloaderImpl;

/// Web-implementatie: volledige pagina-reload.
class _WebReloader implements base.AppReloaderImpl {
  @override
  Future<void> hardReload() async {
    web.window.location.reload();
  }
}

/// Factory voor web.
base.AppReloaderImpl getAppReloader() => _WebReloader();
