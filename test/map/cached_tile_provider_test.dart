import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:glados/glados.dart';
import 'package:lotti/map/cached_tile_provider.dart';

void main() {
  group('CachedTileProvider', () {
    late CachedTileProvider provider;
    late TileLayer tileLayer;

    setUp(() {
      tileLayer = TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
    });

    test('headers reach the image provider produced by getImage', () {
      final headers = {'User-Agent': 'test-app'};
      provider = CachedTileProvider(headers: headers);
      const coordinates = TileCoordinates(0, 0, 1);

      final imageProvider =
          provider.getImage(coordinates, tileLayer)
              as CachedNetworkImageProvider;

      expect(imageProvider.headers, headers);
    });

    test('getImage returns CachedNetworkImageProvider', () {
      provider = CachedTileProvider();
      const coordinates = TileCoordinates(0, 0, 1);

      final imageProvider = provider.getImage(coordinates, tileLayer);

      expect(imageProvider, isA<CachedNetworkImageProvider>());
    });

    test('getImage passes headers to CachedNetworkImageProvider', () {
      final headers = {
        'User-Agent': 'com.example.app',
        'Custom-Header': 'test',
      };
      provider = CachedTileProvider(headers: headers);
      const coordinates = TileCoordinates(0, 0, 1);

      final imageProvider =
          provider.getImage(coordinates, tileLayer)
              as CachedNetworkImageProvider;

      // headers is a public field on CachedNetworkImageProvider, so assert the
      // actual forwarded map rather than using the URL as a proxy.
      expect(imageProvider.headers, equals(headers));
    });

    test('getTileUrl generates correct URL format', () {
      provider = CachedTileProvider();
      const coordinates = TileCoordinates(10, 20, 5);

      final url = provider.getTileUrl(coordinates, tileLayer);

      expect(url, equals('https://tile.openstreetmap.org/5/10/20.png'));
    });

    test('getTileUrl handles different URL templates', () {
      provider = CachedTileProvider();
      final customTileLayer = TileLayer(
        urlTemplate: 'https://example.com/tiles/{z}/{x}/{y}.jpg?key=123',
      );
      const coordinates = TileCoordinates(15, 25, 8);

      final url = provider.getTileUrl(coordinates, customTileLayer);

      expect(url, equals('https://example.com/tiles/8/15/25.jpg?key=123'));
    });

    test('getTileUrl handles subdomains correctly', () {
      provider = CachedTileProvider();
      final subdomainTileLayer = TileLayer(
        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
      const coordinates = TileCoordinates(0, 0, 1);

      final url = provider.getTileUrl(coordinates, subdomainTileLayer);

      // The URL should contain one of the subdomains
      expect(
        url,
        matches(RegExp(r'https://[abc]\.tile\.openstreetmap\.org/1/0/0\.png')),
      );
    });

    test('omitted headers yield a provider with empty headers', () {
      provider = CachedTileProvider();
      const coordinates = TileCoordinates(0, 0, 1);

      final imageProvider =
          provider.getImage(coordinates, tileLayer)
              as CachedNetworkImageProvider;

      expect(imageProvider.headers ?? const <String, String>{}, isEmpty);
    });

    test('empty headers map is handled correctly', () {
      final provider = CachedTileProvider(headers: {});
      const coordinates = TileCoordinates(0, 0, 1);

      final imageProvider = provider.getImage(coordinates, tileLayer);

      expect(imageProvider, isA<CachedNetworkImageProvider>());
    });

    // getTileUrl is inherited from flutter_map's TileProvider; this pins the
    // {z}/{x}/{y} substitution contract the wrapper relies on for any
    // coordinate triple, not just the hand-picked examples above.
    Glados3(any.int, any.int, any.int).test(
      'getTileUrl substitutes z/x/y into the template for any coordinates',
      (x, y, z) {
        final provider = CachedTileProvider();
        final layer = TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        );
        final url = provider.getTileUrl(TileCoordinates(x, y, z), layer);
        expect(
          url,
          equals('https://tile.openstreetmap.org/$z/$x/$y.png'),
        );
      },
      tags: 'glados',
    );
  });
}
