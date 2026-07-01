import 'package:flutter/material.dart';

/// Paleta y tema de la app. Cambiar [kAccent] recolorea toda la interfaz.
const Color kAccent = Color(0xFF7C4DFF); // violeta cinematográfico
const Color kBackground = Color(0xFF0D0E12); // casi negro (AMOLED-friendly)
const Color kSurface = Color(0xFF15161C);
const Color kSurfaceHigh = Color(0xFF1E2029);

/// Tema oscuro premium: superficies casi negras, acento violeta, tarjetas
/// redondeadas con profundidad sutil y tipografía jerarquizada.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kAccent,
    brightness: Brightness.dark,
  ).copyWith(
    surface: kSurface,
    surfaceContainerLowest: kBackground,
    surfaceContainerHighest: kSurfaceHigh,
    primary: kAccent,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBackground,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: kSurface,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF101119),
      indicatorColor: kAccent.withValues(alpha: 0.22),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: const Color(0xFF101119),
      indicatorColor: kAccent.withValues(alpha: 0.22),
      selectedIconTheme: const IconThemeData(color: kAccent),
      selectedLabelTextStyle:
          const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: const TextStyle(color: Colors.white60),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        textStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kSurfaceHigh,
      side: BorderSide.none,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: const DividerThemeData(color: Colors.white10, thickness: 1),
    listTileTheme: const ListTileThemeData(iconColor: Colors.white70),
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
  );
}
