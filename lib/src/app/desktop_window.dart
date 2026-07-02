import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// Gestión de la ventana solo en escritorio (pantalla completa real).
bool get isDesktopWindow =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// Inicializa window_manager (llamar una vez en main, solo escritorio).
Future<void> initDesktopWindow() async {
  if (!isDesktopWindow) return;
  await windowManager.ensureInitialized();
}

/// Pone o quita la pantalla completa del sistema. No-op fuera de escritorio.
Future<void> setWindowFullScreen(bool value) async {
  if (!isDesktopWindow) return;
  try {
    await windowManager.setFullScreen(value);
  } catch (_) {}
}

/// Cambia el título de la ventana (marca white-label). No-op fuera de
/// escritorio.
Future<void> setWindowTitle(String title) async {
  if (!isDesktopWindow) return;
  try {
    await windowManager.setTitle(title);
  } catch (_) {}
}

/// Dimensiona la ventana principal a un tamaño cómodo proporcional a la
/// pantalla (≈62% de ancho y 82% de alto, con topes) y la centra. Maximizar
/// sin más queda mal en monitores ultrapanorámicos. No-op fuera de escritorio.
Future<void> sizeWindowComfortably() async {
  if (!isDesktopWindow) return;
  try {
    final display = await screenRetriever.getPrimaryDisplay();
    final w = (display.size.width * 0.62).clamp(1280.0, 2100.0);
    final h = (display.size.height * 0.82).clamp(720.0, 1400.0);
    await windowManager.setSize(Size(w, h));
    await windowManager.center();
  } catch (_) {}
}
