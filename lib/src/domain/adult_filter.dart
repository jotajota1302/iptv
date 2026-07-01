// Palabras clave para detectar contenido para adultos en nombres de categoría
// o de ítem. Se evitan términos ambiguos (p. ej. "sex" a secas marcaría
// "La Sexta"); se usan formas específicas.
const _adultKeywords = [
  'adult',
  'adulto',
  'para adultos',
  '+18',
  '18+',
  'xxx',
  'porn',
  'erotic',
  'erótic',
  'sexo',
  'brazzers',
  'playboy',
  'hustler',
  'onlyfans',
];

/// True si el nombre parece de contenido para adultos.
bool isAdult(String? name) {
  if (name == null) return false;
  final n = name.toLowerCase();
  return _adultKeywords.any(n.contains);
}
