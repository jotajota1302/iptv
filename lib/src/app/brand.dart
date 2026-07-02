import 'dart:ui';

/// Configuración de marca (white-label). Se fija en tiempo de compilación
/// con --dart-define; sin defines la app es la marca propia:
///
/// ```
/// flutter build windows --release \
///   --dart-define=BRAND_NAME="Acme TV" \
///   --dart-define=BRAND_ACCENT=FF00A5FF \
///   --dart-define=BRAND_SERVER=http://portal.acme.tv:8080
/// ```
class Brand {
  static const name =
      String.fromEnvironment('BRAND_NAME', defaultValue: 'IPTV Player');

  static const _accentHex = String.fromEnvironment('BRAND_ACCENT');

  /// Servidor Xtream fijo del proveedor. Si está definido, la app entra en
  /// modo proveedor: login con usuario/contraseña y sin URLs visibles.
  static const server = String.fromEnvironment('BRAND_SERVER');

  static bool get isWhiteLabel => server.isNotEmpty;

  /// Acento de la marca, o null para usar el violeta por defecto.
  static Color? get accent => parseHexColor(_accentHex);

  /// Feed de actualizaciones (formato API de GitHub Releases). Un white-label
  /// puede apuntar a su propio endpoint o desactivarlo con UPDATE_FEED=off.
  static const _feed = String.fromEnvironment('UPDATE_FEED',
      defaultValue:
          'https://api.github.com/repos/jotajota1302/iptv/releases?per_page=10');

  static String get updateFeed => _feed == 'off' ? '' : _feed;
}

/// 'FF00A5FF', '00A5FF' o '#00A5FF' → Color (ARGB). Null si no parsea.
Color? parseHexColor(String hex) {
  final h = hex.replaceFirst('#', '').trim();
  if (h.length != 6 && h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return null;
  return Color(h.length == 6 ? (0xFF000000 | v) : v);
}
