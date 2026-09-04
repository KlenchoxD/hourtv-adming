/// Caricaturas fijas para elegir al crear un perfil: cada `id` se guarda en
/// el perfil y siempre resuelve a la misma semilla de DiceBear, para que el
/// dibujo elegido no cambie si el usuario luego renombra el perfil.
class HourTvAvatarOption {
  const HourTvAvatarOption(this.id, this.seed, this.label);
  final String id;
  final String seed;
  final String label;
}

class HourTvAvatarCatalog {
  const HourTvAvatarCatalog._();

  // Minimo 6 caricaturas de adultos (mezcla de hombres y mujeres) para el
  // perfil normal. La etiqueta describe el dibujo, no sugiere un nombre de
  // perfil: el nombre lo escribe la persona en el paso siguiente.
  static const adults = [
    HourTvAvatarOption('m1', 'hourtv-adult-m1', 'Hombre 1'),
    HourTvAvatarOption('m2', 'hourtv-adult-m2', 'Hombre 2'),
    HourTvAvatarOption('m3', 'hourtv-adult-m3', 'Hombre 3'),
    HourTvAvatarOption('f1', 'hourtv-adult-f1', 'Mujer 1'),
    HourTvAvatarOption('f2', 'hourtv-adult-f2', 'Mujer 2'),
    HourTvAvatarOption('f3', 'hourtv-adult-f3', 'Mujer 3'),
  ];

  // Para el perfil infantil: una niña y un niño.
  static const kids = [
    HourTvAvatarOption('boy', 'hourtv-kid-boy', 'Niño'),
    HourTvAvatarOption('girl', 'hourtv-kid-girl', 'Niña'),
  ];

  static String seedFor(String avatarId) {
    for (final option in [...adults, ...kids]) {
      if (option.id == avatarId) return option.seed;
    }
    return avatarId;
  }
}
