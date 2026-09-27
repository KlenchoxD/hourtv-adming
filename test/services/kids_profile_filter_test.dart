import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/parental_control_service.dart';
import 'package:streamtv/services/storage_service.dart';

Channel _movie(
  String name,
  String genre, [
  List<String> categories = const [],
]) => Channel(
  name: name,
  url: 'https://cdn.example/movie/$name.mp4',
  genre: genre,
  categories: categories,
);

Channel _live(String name, {String? group}) => Channel(
  name: name,
  url: 'https://cdn.example/live/$name.m3u8',
  group: group,
);

void main() {
  test('perfil infantil: pasa lo de niños y no lo que no es apto', () {
    bool kids(Channel c) => ParentalControlService.isKidsChannel(c);

    // Aptos.
    expect(kids(_movie('Toy Story 5', 'Animación, Familia, Comedia')), isTrue);
    expect(
      kids(_movie('Coco', 'Familia, Animación, Música, Aventura')),
      isTrue,
    );
    expect(
      kids(
        _movie(
          'Minions: El origen de Gru',
          'Animación, Comedia, Crimen, Familia',
        ),
      ),
      isTrue,
    );
    // El panel le puso categoría "terror" pero también "infantil".
    expect(
      kids(
        _movie(
          '¡Scooby Doo! ¡Y Krypto también!',
          'Animación, Familia, Misterio',
          ['familia', 'terror', 'infantil'],
        ),
      ),
      isTrue,
    );
    expect(kids(_movie('Matilda', 'Comedia, Familia, Fantasía')), isTrue);

    // No aptos.
    expect(kids(_movie('Hazbin Hotel', 'Animación, Comedia, Drama')), isFalse);
    expect(
      kids(_movie('Tokyo Ghoul', 'Animación, Anime, Acción, Terror')),
      isFalse,
    );
    expect(kids(_movie('Deadpool', 'Acción, Comedia, Aventura')), isFalse);
    expect(
      kids(
        _movie(
          'Bob Esponja: Campamento del Terror',
          'Familia, Comedia, Terror',
        ),
      ),
      isFalse,
    );
    expect(
      kids(_movie('Dragon Ball Super', 'Animación, Anime, Acción')),
      isFalse,
    );

    // En vivo: solo canales infantiles.
    expect(kids(_live('Disney Junior')), isTrue);
    expect(kids(_live('Cartoon Network')), isTrue);
    expect(kids(_live('Canal 5', group: 'Kids')), isTrue);
    expect(kids(_live('Win Sports', group: 'Sports')), isFalse);
    expect(kids(_live('Noticias RCN', group: 'News')), isFalse);
  });

  test('solo filtra con el perfil infantil activo', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final items = [
      _movie('Coco', 'Familia, Animación'),
      _movie('Deadpool', 'Acción, Comedia'),
    ];

    expect(ParentalControlService.filterChannels(items), hasLength(2));

    await StorageService.saveSetting('activeProfileIsKids', true);
    expect(ParentalControlService.filterChannels(items).map((c) => c.name), [
      'Coco',
    ]);
  });
}
