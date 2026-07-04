import os

base = r"C:\Users\Kleiner\proyectos\mi_app"

test = """import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('placeholder', (WidgetTester tester) async {
    expect(true, isTrue);
  });
}
"""

with open(os.path.join(base, 'test', 'widget_test.dart'), 'w', encoding='utf-8') as f:
    f.write(test)
print("widget_test.dart written")