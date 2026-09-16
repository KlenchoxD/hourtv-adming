import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/device_type.dart';

void main() {
  setUp(() {
    DeviceProfile.overrideType.value = null;
    AdaptiveProfile.overrideLayoutSize.value = null;
    AdaptiveProfile.overrideInputMode.value = null;
  });

  tearDown(() {
    DeviceProfile.overrideType.value = null;
    AdaptiveProfile.overrideLayoutSize.value = null;
    AdaptiveProfile.overrideInputMode.value = null;
  });

  group('AdaptiveProfile Bidimensional Resolution', () {
    testWidgets('resolves compact layout for width < 600', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late AdaptiveProfileData profile;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              profile = AdaptiveProfile.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(profile.layoutSize, AdaptiveLayoutSize.compact);
      expect(profile.isCompact, isTrue);
      expect(profile.isMedium, isFalse);
      expect(profile.isExpanded, isFalse);
    });

    testWidgets('resolves medium layout for 600 <= width < 1024', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late AdaptiveProfileData profile;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              profile = AdaptiveProfile.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(profile.layoutSize, AdaptiveLayoutSize.medium);
      expect(profile.isMedium, isTrue);
      expect(profile.isCompact, isFalse);
      expect(profile.isExpanded, isFalse);
    });

    testWidgets('resolves expanded layout for width >= 1024', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late AdaptiveProfileData profile;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              profile = AdaptiveProfile.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(profile.layoutSize, AdaptiveLayoutSize.expanded);
      expect(profile.isExpanded, isTrue);
      expect(profile.isCompact, isFalse);
      expect(profile.isMedium, isFalse);
    });

    testWidgets('maps DeviceType.tv override to dpad input mode and expanded/tv', (tester) async {
      DeviceProfile.overrideType.value = DeviceType.tv;
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late AdaptiveProfileData profile;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              profile = AdaptiveProfile.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(profile.inputMode, AdaptiveInputMode.dpad);
      expect(profile.isDpad, isTrue);
      expect(DeviceProfile.isTv(tester.element(find.byType(SizedBox))), isTrue);
    });

    testWidgets('allows independent overrides for layoutSize and inputMode', (tester) async {
      AdaptiveProfile.overrideLayoutSize.value = AdaptiveLayoutSize.compact;
      AdaptiveProfile.overrideInputMode.value = AdaptiveInputMode.dpad;

      late AdaptiveProfileData profile;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              profile = AdaptiveProfile.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(profile.layoutSize, AdaptiveLayoutSize.compact);
      expect(profile.inputMode, AdaptiveInputMode.dpad);
      expect(profile.isCompact, isTrue);
      expect(profile.isDpad, isTrue);
    });

    testWidgets('preserves legacy DeviceProfile behavior', (tester) async {
      DeviceProfile.overrideType.value = DeviceType.phone;

      late DeviceType legacyType;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              legacyType = DeviceProfile.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(legacyType, DeviceType.phone);
      expect(DeviceProfile.isPhone(tester.element(find.byType(SizedBox))), isTrue);
      expect(DeviceProfile.isTv(tester.element(find.byType(SizedBox))), isFalse);
    });
  });
}
