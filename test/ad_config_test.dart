import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/ads/ad_config.dart';

void main() {
  test('lee las claves de Unity desde app_config.json', () {
    final config = AdConfig.fromJson({
      'ads': {
        'levelPlay': true,
        'levelPlayAppKey': 'abc123',
        'levelPlayInterstitialId': 'unit9',
      },
    });
    expect(config.hasLevelPlay, isTrue);
    expect(config.levelPlayAppKey, 'abc123');
    expect(config.levelPlayInterstitialId, 'unit9');
  });

  test('se pueden apagar desde el panel', () {
    final config = AdConfig.fromJson({
      'ads': {
        'levelPlay': false,
        'levelPlayAppKey': 'abc',
        'levelPlayInterstitialId': 'u',
      },
    });
    expect(config.hasLevelPlay, isFalse);
  });

  test('sin app_config.json se usan las claves de fábrica', () {
    final config = AdConfig.fromJson({});
    expect(config.hasLevelPlay, isTrue);
    expect(config.levelPlayAppKey, '2862a1335');
    expect(config.levelPlayInterstitialId, 'k4kyfg81dmv52b4e');
  });
}
