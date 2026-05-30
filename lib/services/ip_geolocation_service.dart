import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/geohash.dart';

typedef IpGeolocationProvider =
    Future<Geolocation?> Function({http.Client? httpClient});

IpGeolocationProvider get defaultIpGeolocationProvider =>
    IpGeolocationService.getLocationFromIp;

class IpGeolocationService {
  static const String _ipApiUrl = 'https://ipapi.co/json/';
  static const String _ipApiFallbackUrl = 'https://ip-api.com/json';
  static const Duration _timeout = Duration(seconds: 5);
  static const double _ipLocationAccuracy =
      50000; // ~50km accuracy for IP geolocation

  static Future<Geolocation?> getLocationFromIp({
    http.Client? httpClient,
    DateTime Function()? clock,
  }) async {
    final client = httpClient ?? http.Client();
    final now = (clock ?? DateTime.now)();
    try {
      final response = await client
          .get(
            Uri.parse(_ipApiUrl),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        final latitude = (data['latitude'] as num?)?.toDouble();
        final longitude = (data['longitude'] as num?)?.toDouble();

        if (latitude != null && longitude != null) {
          return Geolocation(
            createdAt: now,
            latitude: latitude,
            longitude: longitude,
            geohashString: getGeoHash(
              latitude: latitude,
              longitude: longitude,
            ),
            timezone: data['timezone'] as String? ?? now.timeZoneName,
            utcOffset: data['utc_offset'] != null
                ? _parseUtcOffset(data['utc_offset'] as String, now)
                : now.timeZoneOffset.inMinutes,
            accuracy: _ipLocationAccuracy,
          );
        }
      }
    } catch (e) {
      getIt<DomainLogger>().error(
        LogDomain.location,
        e,
        subDomain: 'getLocationFromIp',
      );
    }

    return _getLocationFromIpApiFallback(httpClient: client, now: now);
  }

  static int _parseUtcOffset(String offset, DateTime now) {
    // Parse offset format like "+0200" or "-0430"
    try {
      if (offset.isEmpty) return 0;

      final sign = offset.startsWith('-') ? -1 : 1;
      final cleanOffset = offset.replaceAll(RegExp('[+-]'), '');

      if (cleanOffset.length >= 4) {
        final hours = int.parse(cleanOffset.substring(0, 2));
        final minutes = int.parse(cleanOffset.substring(2, 4));
        return sign * (hours * 60 + minutes);
      }
    } catch (e) {
      getIt<DomainLogger>().error(
        LogDomain.location,
        e,
        subDomain: '_parseUtcOffset',
      );
    }

    return now.timeZoneOffset.inMinutes;
  }

  // Alternative fallback using ip-api.com
  static Future<Geolocation?> _getLocationFromIpApiFallback({
    required http.Client httpClient,
    required DateTime now,
  }) async {
    try {
      final response = await httpClient
          .get(
            Uri.parse(_ipApiFallbackUrl),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'success') {
          final latitude = (data['lat'] as num?)?.toDouble();
          final longitude = (data['lon'] as num?)?.toDouble();

          if (latitude != null && longitude != null) {
            return Geolocation(
              createdAt: now,
              latitude: latitude,
              longitude: longitude,
              geohashString: getGeoHash(
                latitude: latitude,
                longitude: longitude,
              ),
              timezone: data['timezone'] as String? ?? now.timeZoneName,
              utcOffset: data['offset'] != null
                  ? (data['offset'] as num).toInt() ~/ 60
                  : now.timeZoneOffset.inMinutes,
              accuracy: _ipLocationAccuracy,
            );
          }
        }
      }
    } catch (e) {
      getIt<DomainLogger>().error(
        LogDomain.location,
        e,
        subDomain: '_getLocationFromIpApiFallback',
      );
    }

    return null;
  }
}
