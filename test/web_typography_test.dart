import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('web usa sans serif y la app conserva Roboto Serif', (
    tester,
  ) async {
    final theme = HourTvMobileTheme.build(web: true);
    expect(theme.textTheme.bodyMedium?.fontFamily, startsWith('Inter'));
    expect(
      HourTvMobileTheme.build(web: false).textTheme.bodyMedium?.fontFamily,
      startsWith('RobotoSerif'),
    );
  });
}
