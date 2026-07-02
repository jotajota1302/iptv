/// URL reproducible del tráiler a partir del campo `youtube_trailer` de la
/// API Xtream: puede venir como URL completa o como id de vídeo de YouTube.
/// Null si no hay tráiler.
String? trailerUrl(String? raw) {
  final v = raw?.trim() ?? '';
  if (v.isEmpty) return null;
  if (v.startsWith('http://') || v.startsWith('https://')) return v;
  return 'https://www.youtube.com/watch?v=$v';
}
