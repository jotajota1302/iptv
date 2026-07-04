import 'media_item.dart';

/// Un episodio dentro de una serie: el item multimedia con su temporada y número.
class Episode {
  final MediaItem item;
  final int season;
  final int episode;
  const Episode(
      {required this.item, required this.season, required this.episode});
}

/// Una serie agrupada: título común, carátula y sus temporadas con episodios.
class SeriesGroup {
  final String title;
  final String? poster;
  final Map<int, List<Episode>> seasons;
  const SeriesGroup(
      {required this.title, this.poster, required this.seasons});

  /// Números de temporada ordenados ascendentemente.
  List<int> get sortedSeasons => seasons.keys.toList()..sort();

  /// Total de episodios en todas las temporadas.
  int get episodeCount =>
      seasons.values.fold(0, (sum, list) => sum + list.length);

  /// Año de estreno de la serie: el mayor año entre sus episodios (tomado del
  /// título del proveedor). 0 = desconocido si ninguno lo trae.
  int get year {
    var max = 0;
    for (final list in seasons.values) {
      for (final e in list) {
        if (e.item.releaseYear > max) max = e.item.releaseYear;
      }
    }
    return max;
  }

  /// Marca de "recién añadido" de la serie: el mayor addedAt entre sus
  /// episodios (el episodio más recientemente añadido a la lista).
  int get addedAt {
    var max = 0;
    for (final list in seasons.values) {
      for (final e in list) {
        if (e.item.addedAt > max) max = e.item.addedAt;
      }
    }
    return max;
  }
}
