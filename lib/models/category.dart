import 'package:flutter/material.dart';

class Category {
  final String name;
  final IconData iconData;
  final Color color;

  const Category({
    required this.name,
    required this.iconData,
    required this.color,
  });

  static const List<Category> defaultCategories = [
    Category(name: 'Todos', iconData: Icons.apps, color: Color(0xFF6366F1)),
    Category(name: 'Favoritos', iconData: Icons.favorite, color: Color(0xFFEF4444)),
    Category(name: 'Latinos', iconData: Icons.public, color: Color(0xFF10B981)),
    Category(name: 'Espana', iconData: Icons.flag, color: Color(0xFFF59E0B)),
    Category(name: 'USA', iconData: Icons.flag_outlined, color: Color(0xFF3B82F6)),
    Category(name: 'Deportes', iconData: Icons.sports_soccer, color: Color(0xFF22C55E)),
    Category(name: 'Peliculas', iconData: Icons.movie, color: Color(0xFFEAB308)),
    Category(name: 'Infantiles', iconData: Icons.child_care, color: Color(0xFFEC4899)),
    Category(name: 'Musica', iconData: Icons.music_note, color: Color(0xFF8B5CF6)),
    Category(name: 'Noticias', iconData: Icons.newspaper, color: Color(0xFF64748B)),
    Category(name: 'Documentales', iconData: Icons.video_library, color: Color(0xFF14B8A6)),
  ];
}
