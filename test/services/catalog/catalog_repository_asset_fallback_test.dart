import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';

void main() {
  test('bundled fallback never imports prototype movies or series', () async {
    final payload = await CatalogRepository.loadAssetSources();

    expect(payload.series, isEmpty);
    expect(
      payload.channels.where((channel) => channel.type != MediaType.live),
      isEmpty,
    );
    expect(
      payload.lists.where(
        (list) => list.mediaType == 'movie' || list.mediaType == 'series',
      ),
      isEmpty,
    );
  });
}
