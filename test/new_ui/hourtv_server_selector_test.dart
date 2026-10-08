import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_server_selector.dart';

void main() {
  for (final size in [const Size(360, 800), const Size(800, 360)]) {
    testWidgets('all seven servers remain selectable at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final servers = List.generate(
        7,
        (i) => ChannelServer(
          name: 'TokiAnime',
          url: 'https://example.invalid/$i',
          language: i < 4 ? 'Español Latino' : 'Subtitulado',
        ),
      );
      ChannelServer? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showDialog<ChannelServer>(
                    context: context,
                    builder: (_) => HourTvServerSelector(
                      servers: servers,
                      activeUrl: servers.first.url,
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final header = tester.getRect(find.text('Servidores'));
      expect(header.top, greaterThanOrEqualTo(0));
      await tester.scrollUntilVisible(
        find.text('TokiAnime · 7'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('TokiAnime · 7'));
      await tester.pumpAndSettle();
      expect(selected, same(servers.last));
      expect(tester.takeException(), isNull);
    });
  }
}
