import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'hourtv_profile_avatars.dart';

/// Avatar de perfil generado por DiceBear (dicebear.com, gratis, sin API
/// key): el mismo nombre de perfil siempre produce el mismo dibujo, como los
/// avatares fijos de Netflix/HBO/Prime, en vez de una simple inicial o un
/// icono generico.
String profileAvatarUrl(String profileName) =>
    'https://api.dicebear.com/9.x/adventurer/png'
    '?seed=${Uri.encodeComponent(profileName)}&size=200';

class HourTvProfileAvatar extends StatelessWidget {
  const HourTvProfileAvatar({
    super.key,
    required this.profileName,
    required this.radius,
    this.backgroundColor = const Color(0xFF00C781),
    this.avatarSeed,
  });

  final String profileName;
  final double radius;
  final Color backgroundColor;

  /// Semilla fija elegida al crear el perfil (una de las caricaturas del
  /// selector). Si no se da (avatares viejos o casos genericos), se usa el
  /// nombre del perfil como semilla, como antes.
  final String? avatarSeed;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return ClipOval(
      child: CachedNetworkImage(
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        // Acepta el id del catálogo ("m1") o la semilla: antes varias
        // pantallas pasaban el id guardado y dibujaban otra caricatura.
        imageUrl: profileAvatarUrl(
          HourTvAvatarCatalog.seedFor(avatarSeed ?? profileName),
        ),
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => _fallback(),
        errorWidget: (_, _, _) => _fallback(),
      ),
    );
  }

  // Sin conexion o si la API falla: circulo de color + icono, nunca una
  // celda vacia o rota.
  Widget _fallback() {
    final size = radius * 2;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: backgroundColor),
      child: Icon(Icons.person_rounded, color: Colors.white, size: radius),
    );
  }
}
