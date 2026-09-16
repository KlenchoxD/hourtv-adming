/// Generador de Hero tags deterministas con alcance contextual para evitar colisiones
/// entre la misma película/serie en distintas secciones (e.g. Tendencias vs Recomendados vs Búsqueda).
String makeHeroTag({required String contextScope, required String id}) {
  final cleanScope = contextScope.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final cleanId = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  return 'hero_${cleanScope}_$cleanId';
}
