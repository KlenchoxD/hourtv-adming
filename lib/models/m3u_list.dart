import 'dart:convert';

class M3UList {
  final String name;
  final String url;
  final String? description;
  final String? icon;
  final String? category;
  final bool isDefault;
  final DateTime? lastUpdated;
  // Credenciales Xtream (solo cuando category == 'xtream'), para pedir el VOD
  // por la API player_api.php (peliculas y series no vienen en el m3u).
  final String? host;
  final String? username;
  final String? password;
  // Tipo de contenido de la lista: 'live' (canales), 'movie' (películas) o
  // 'series'. Fuerza la clasificación al parsear (para M3U que no traen /movie/).
  final String? mediaType;

  M3UList({
    required this.name,
    required this.url,
    this.description,
    this.icon,
    this.category,
    this.isDefault = false,
    this.lastUpdated,
    this.host,
    this.username,
    this.password,
    this.mediaType,
  });

  bool get isXtream => category == 'xtream' && username != null && password != null && host != null;

  factory M3UList.fromJson(Map<String, dynamic> json) {
    return M3UList(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      description: json['description'],
      icon: json['icon'],
      category: json['category'],
      isDefault: json['isDefault'] ?? json['is_default'] ?? false,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'])
          : null,
      host: json['host'],
      username: json['username'],
      password: json['password'],
      mediaType: json['mediaType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'description': description,
      'icon': icon,
      'category': category,
      'isDefault': isDefault,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'host': host,
      'username': username,
      'password': password,
      'mediaType': mediaType,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static M3UList fromJsonString(String jsonString) {
    return M3UList.fromJson(jsonDecode(jsonString));
  }
}
