/// Idiomas seleccionables como preferidos (código → nombre visible).
const kPreferredLangs = <(String, String)>[
  ('', 'Automático'),
  ('es', 'Español'),
  ('en', 'Inglés'),
  ('fr', 'Francés'),
  ('de', 'Alemán'),
  ('it', 'Italiano'),
  ('pt', 'Portugués'),
];

const _aliases = <String, Set<String>>{
  'es': {'es', 'spa', 'esp', 'cas', 'castellano', 'spanish', 'español'},
  'en': {'en', 'eng', 'english', 'ingles', 'inglés'},
  'fr': {'fr', 'fra', 'fre', 'french', 'francés'},
  'de': {'de', 'deu', 'ger', 'german', 'alemán'},
  'it': {'it', 'ita', 'italian', 'italiano'},
  'pt': {'pt', 'por', 'portuguese', 'portugués'},
};

/// True si el idioma que reporta la pista ([trackLang], código ISO o nombre
/// libre tipo "Spanish") corresponde al preferido [pref] ('es', 'en'...).
bool langMatches(String? trackLang, String pref) {
  if (trackLang == null || trackLang.isEmpty || pref.isEmpty) return false;
  final t = trackLang.toLowerCase().trim();
  final aliases = _aliases[pref] ?? {pref};
  if (aliases.contains(t)) return true;
  // Nombres largos ("Spanish (Latin America)") contienen el alias textual.
  return aliases.any((a) => a.length > 3 && t.contains(a));
}
