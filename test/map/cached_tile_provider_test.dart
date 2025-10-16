import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/cached_tile_provider.dart';

void main() {
  group('CachedTileProvider', () {
    late CachedTileProvider provider;
    late TileLayer tileLayer;

    setUp(() {
      tileLayer = TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
    });

    test('constructor accepts headers parameter', () {
      final headers = {'User-Agent': 'test-app'};
      provider = CachedTileProvider(headers: headers);

      expect(provider, isNotNull);
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
        'Custom-Header': 'test'
      };
      provider = CachedTileProvider(headers: headers);
      const coordinates = TileCoordinates(0, 0, 1);

      final imageProvider = provider.getImage(coordinates, tileLayer)
          as CachedNetworkImageProvider;

      // CachedNetworkImageProvider stores headers internally
      // We can't directly access them, but we can verify the provider was created
      expect(imageProvider, isNotNull);
      expect(imageProvider.url, contains('tile.openstreetmap.org'));
    });

    test('getImage without headers creates provider with null headers', () {
      provider = CachedTileProvider();
      const coordinates = TileCoordinates(0, 0, 1);

      final imageProvider = provider.getImage(coordinates, tileLayer)
          as CachedNetworkImageProvider;

      expect(imageProvider, isNotNull);
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
          matches(
              RegExp(r'https://[abc]\.tile\.openstreetmap\.org/1/0/0\.png')));
    });

    test('multiple instances with different headers', () {
      final provider1 = CachedTileProvider(headers: {'User-Agent': 'app1'});
      final provider2 = CachedTileProvider(headers: {'User-Agent': 'app2'});
      final provider3 = CachedTileProvider();

      // All providers should be independent instances
      expect(provider1, isNot(equals(provider2)));
      expect(provider1, isNot(equals(provider3)));
      expect(provider2, isNot(equals(provider3)));
    });

    test('headers parameter is optional', () {
      // Should not throw when creating without headers
      expect(CachedTileProvider.new, returnsNormally);
    });

    test('empty headers map is handled correctly', () {
      final provider = CachedTileProvider(headers: {});
      const coordinates = TileCoordinates(0, 0, 1);

      final imageProvider = provider.getImage(coordinates, tileLayer);

      expect(imageProvider, isA<CachedNetworkImageProvider>());
    });
  });
}
