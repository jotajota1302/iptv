import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/app/brand.dart';
import 'src/app/desktop_window.dart';
import 'src/app/providers.dart';
import 'src/app/theme.dart';
import 'src/app/viewer_args.dart';
import 'src/ui/app_shell.dart';
import 'src/ui/player_screen.dart';

/// Permite arrastrar los scrolls (carruseles, rails) con el ratón en escritorio.
/// Por defecto Flutter solo permite arrastre con dedo/trackpad.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await initDesktopWindow();
  final prefs = await SharedPreferences.getInstance();
  // Color de acento: preferencia del usuario > acento de la marca > violeta.
  final accentPref = prefs.getInt('accent_color');
  kAccent = accentPref != null
      ? kAccentChoices[accentPref.clamp(0, kAccentChoices.length - 1)].$2
      : (Brand.accent ?? kAccent);
  // Modo visor: lanzado con `--play <url>` desde la ventana principal, esta
  // instancia es solo una ventana de reproducción independiente.
  final viewer = parseViewerArgs(args);
  if (viewer == null) setWindowTitle(Brand.name);
  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: viewer == null ? const IptvApp() : ViewerApp(args: viewer),
  ));
}

/// App mínima del modo visor: solo el reproductor, sin navegación ni acceso a
/// la base de datos (evita contención de SQLite entre procesos).
class ViewerApp extends StatelessWidget {
  final ViewerArgs args;
  const ViewerApp({super.key, required this.args});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: args.name,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      scrollBehavior: AppScrollBehavior(),
      home: PlayerScreen(item: args.toItem(), viewerWindow: true),
    );
  }
}

class IptvApp extends ConsumerWidget {
  const IptvApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Al cambiar el acento en Ajustes se reconstruye el tema entero.
    ref.watch(accentIndexProvider);
    return MaterialApp(
      title: Brand.name,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      scrollBehavior: AppScrollBehavior(),
      home: const AppShell(),
    );
  }
}
