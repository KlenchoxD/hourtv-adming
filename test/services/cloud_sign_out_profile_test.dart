import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  test('cerrar sesión obliga a elegir perfil también tras reiniciar', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.setCloudProfileContext(
      accountId: 'acc',
      profileId: 'p1',
      name: 'Kleiner',
      avatarId: 'boy',
      isKids: false,
    );
    await StorageService.markProfileChosen();

    await StorageService.clearCloudProfileContext();
    expect(StorageService.hasChosenProfile.value, isFalse);

    // Reinicio de la app: se relee lo guardado.
    await StorageService.init();
    expect(StorageService.hasChosenProfile.value, isFalse);
  });
}
