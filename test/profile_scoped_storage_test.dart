import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  test(
    'migrates legacy favorites and history to the active primary profile',
    () async {
      final favorite = Channel(name: 'Favorita', url: 'fav');
      final recent = Channel(name: 'Reciente', url: 'recent');
      SharedPreferences.setMockInitialValues({
        'favorites': jsonEncode([favorite.toJson()]),
        'recent_channels': jsonEncode([recent.toJson()]),
        'settings': jsonEncode({'activeProfile': 'Cinéfilo'}),
      });

      await StorageService.init();

      expect(StorageService.activeProfileId, 'cinefilo');
      expect(StorageService.primaryProfileId, 'cinefilo');
      expect(StorageService.loadFavorites().single.url, 'fav');
      expect(StorageService.loadRecent().single.url, 'recent');
    },
  );

  test(
    'keeps favorites and history isolated when switching profiles',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StorageService.init();

      final invitadoFavorite = Channel(name: 'Uno', url: 'one');
      await StorageService.saveFavorites([invitadoFavorite]);
      await StorageService.saveRecent(Channel(name: 'Visto', url: 'watched'));

      await StorageService.setActiveProfile('Kids');
      expect(StorageService.activeProfileId, 'kids');
      expect(StorageService.loadFavorites(), isEmpty);
      expect(StorageService.loadRecent(), isEmpty);

      await StorageService.saveFavorites([
        Channel(name: 'Infantil', url: 'kids-only'),
      ]);
      await StorageService.setActiveProfile('Invitado');

      expect(StorageService.loadFavorites().single.url, 'one');
      expect(StorageService.loadRecent().single.url, 'watched');
    },
  );
}
