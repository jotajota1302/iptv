import 'dart:io';
import 'package:flutter/foundation.dart';
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
