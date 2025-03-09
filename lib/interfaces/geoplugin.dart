import 'dart:async' show FutureOr;
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' show Client;

class Coordinates {
  static final _earthDiameter = 2 * 6378137.0; // WGS84 major axis
  static double _degToRad(final double degrees) => degrees * (pi / 180.0);

  /// RADIANS
  final double lat, long;
  final String? region;

  Coordinates({required double latDegrees, required double longDegrees, this.region})
      : lat = _degToRad(latDegrees),
        long = _degToRad(longDegrees);
  Coordinates.fromGP(Map<String, dynamic> resp)
      : lat = _degToRad(resp['geoplugin_latitude']),
        long = _degToRad(resp['geoplugin_longitude']),
        region = resp['geoplugin_regionCode'];

  /// The [Haversine Formula](https://en.wikipedia.org/wiki/Haversine_formula) for distance
  double operator -(Coordinates other) =>
      _earthDiameter *
      asin(sqrt(pow(sin(other.lat - lat) / 2, 2) +
          cos(lat) * cos(other.lat) * pow(sin(other.long - long) / 2, 2)));
}

class GeoPlugin {
  static final _client = Client();
  static final _url = Uri.http('geoplugin.net', '/json.gp');

  static Coordinates? _coords;
  static FutureOr<Coordinates?> get coords async {
    if (_coords != null) return _coords!;
    _coords = await _client
        .get(_url)
        .then((resp) => Map<String, dynamic>.from(jsonDecode(resp.body)))
        .then<Coordinates?>(Coordinates.fromGP)
        .catchError((_) => null);
    return _coords;
  }

  static Coordinates? get coordsNow => _coords;
}
