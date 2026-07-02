import '../domain/media_item.dart';
import '../domain/series_group.dart';

// Formatos habituales de numeración: "S01E02" / "s1 e2" y "1x02".
final _reSxxEyy = RegExp(r'[sS](\d{1,3})\s*[eE](\d{1,3})');
final _reNxM = RegExp(r'(?<![\dxX])(\d{1,2})[xX](\d{1,3})(?!\d)');

/// Resultado interno del parseo de un nombre de episodio.
class _Parsed {
  final String title;
  final int season;
  final int episode;
  const _Parsed(this.title, this.season, this.episode);
}

_Parsed _parseName(String name) {
  var m = _reSxxEyy.firstMatch(name);
  m ??= _reNxM.firstMatch(name);
  if (m == null) {
    // Sin patrón: episodio suelto (temporada 0), título = nombre completo.
    return _Parsed(name.trim(), 0, 0);
  }
  final season = int.parse(m.group(1)!);
  final episode = int.parse(m.group(2)!);
  // El título es lo que hay antes del patrón, limpiando separadores colgantes.
  var title = name.substring(0, m.start).trim();
  title = title.replaceAll(RegExp(r'[\s\-:_.]+$'), '').trim();
  if (title.isEmpty) title = name.trim();
  return _Parsed(title, season, episode);
}

String _normalize(String s) => s.toLowerCase().trim();

/// Limpia el nombre crudo de un episodio para mostrarlo dentro de su serie:
/// quita el título de la serie, el patrón de numeración (SxxEyy / NxM) y los
/// separadores colgantes. Puede devolver '' si el nombre no aporta más (el
/// llamador decide el fallback, p. ej. "Episodio N").
String cleanEpisodeName(String name, String seriesTitle) {
  var out = name.trim();
  if (seriesTitle.isNotEmpty) {
    final t = RegExp.escape(seriesTitle.trim());
    out = out.replaceFirst(RegExp(t, caseSensitive: false), '');
  }
  out = out.replaceFirst(_reSxxEyy, '');
  out = out.replaceFirst(_reNxM, '');
  out = out.replaceAll(RegExp(r'^[\s\-:_.]+|[\s\-:_.]+$'), '');
  return out.trim();
}

/// Agrupa una lista de items (episodios) en series por título, y dentro de cada
/// serie por temporada. Ordena series por título y episodios por número.
List<SeriesGroup> groupSeries(List<MediaItem> items) {
  // title normalizado -> (title visible, poster, season -> episodios)
  final byTitle = <String, ({String title, String? poster, Map<int, List<Episode>> seasons})>{};

  for (final it in items) {
    final parsed = _parseName(it.name);
    final key = _normalize(parsed.title);
    final entry = byTitle.putIfAbsent(
      key,
      () => (title: parsed.title, poster: null, seasons: <int, List<Episode>>{}),
    );
    // Fija el primer poster no nulo encontrado.
    if (entry.poster == null && it.logoUrl != null) {
      byTitle[key] = (title: entry.title, poster: it.logoUrl, seasons: entry.seasons);
    }
    final seasons = byTitle[key]!.seasons;
    seasons
        .putIfAbsent(parsed.season, () => <Episode>[])
        .add(Episode(item: it, season: parsed.season, episode: parsed.episode));
  }

  final groups = byTitle.values.map((e) {
    for (final list in e.seasons.values) {
      list.sort((a, b) => a.episode.compareTo(b.episode));
    }
    return SeriesGroup(title: e.title, poster: e.poster, seasons: e.seasons);
  }).toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  return groups;
}
