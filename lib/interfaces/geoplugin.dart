import 'dart:convert';

import 'package:http/http.dart' show Client;

typedef Coordinates = ({double lat, double long});

class GeoPlugin {
  static final _client = Client();
  static final _url = Uri.http('geoplugin.net', '/json.gp');

  static Future<Coordinates> get() => _client
      .get(_url)
      .then((resp) => Map<String, dynamic>.from(jsonDecode(resp.body)))
      .then((data) =>
          (lat: data['geoplugin_latitude'] as double, long: data['geoplugin_longitude'] as double));
}
