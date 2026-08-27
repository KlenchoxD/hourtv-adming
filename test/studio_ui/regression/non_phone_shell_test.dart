import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/hybrid_mobile/hybrid_mobile_shell.dart';
import 'package:streamtv/new_ui/hourtv_new_shell.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
  });

  testWidgets('non-phone layouts do not activate HybridMobileShell', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: HourTvNewShell(forcePhoneForTesting: false)),
    );
    await tester.pump();

    expect(find.byType(HybridMobileShell), findsNothing);
  });

  testWidgets('phone layout activates HybridMobileShell', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: HourTvNewShell(forcePhoneForTesting: true)),
    );
    await tester.pump();

    expect(find.byType(HybridMobileShell), findsOneWidget);
  });
}
