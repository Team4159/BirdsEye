import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/bluealliance.dart';
import '../main.dart' show prefs;

class ConfigurationPage extends StatefulWidget {
  const ConfigurationPage({super.key});

  @override
  State<StatefulWidget> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
  final _eventCarouselController = CarouselController();

  @override
  void initState() {
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    super.initState();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppBar(title: const Text("Configuration")),
        ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height / 8),
            child: FutureBuilder(
                future: Supabase.instance.client
                    .rpc("getavailableseasons")
                    .then((resp) => List<int>.from(resp)..sort()),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return snapshot.hasError ||
                            (snapshot.data?.isEmpty ?? false)
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                                Icon(Icons.warning_rounded,
                                    color: Colors.red[700], size: 50),
                                Text(snapshot.error?.toString() ?? "No Data")
                              ])
                        : const LinearProgressIndicator();
                  }
                  int index = snapshot.data!.indexWhere(
                      (element) => element == Configuration.instance.season);
                  if (Configuration.instance.season < 0 || index < 0) {
                    Configuration.instance.season = snapshot.data![index = 0];
                  }
                  return Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 12),
                      child: CarouselSlider(
                          items: snapshot.data!
                              .map((year) => Text(year.toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium))
                              .toList(),
                          options: CarouselOptions(
                              aspectRatio: 12 / 1,
                              viewportFraction: 1 / 3,
                              enableInfiniteScroll: false,
                              initialPage: index,
                              onPageChanged: (i, _) => Configuration
                                  .instance.season = snapshot.data![i])));
                })),
        Expanded(
            child: ListenableBuilder(
                listenable: Configuration.instance,
                builder: (context, child) => FutureBuilder(
                    future: BlueAlliance.stock.get((
                      season: Configuration.instance.season,
                      event: null,
                      match: null
                    )),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return snapshot.hasError
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                    Icon(Icons.warning_rounded,
                                        color: Colors.red[700], size: 50),
                                    const SizedBox(height: 20),
                                    Text(snapshot.error.toString())
                                  ])
                            : const Center(child: CircularProgressIndicator());
                      }
                      List<MapEntry<String, String>> entries =
                          snapshot.data!.entries.toList();
                      int index = entries.indexWhere(
                          (element) => element.key == Configuration.event);
                      if (!prefs.containsKey("event") || index < 0) {
                        prefs.setString("event", entries[index = 0].key);
                      }
                      return Stack(
                          fit: StackFit.passthrough,
                          alignment: Alignment.center,
                          children: [
                            CarouselSlider(
                                carouselController: _eventCarouselController,
                                items: entries
                                    .asMap()
                                    .entries
                                    .map<Widget>((enumeratedEntry) => ListTile(
                                        visualDensity: VisualDensity
                                            .adaptivePlatformDensity,
                                        title: Text(
                                          enumeratedEntry.value.value,
                                          overflow: kIsWeb
                                              ? TextOverflow.ellipsis
                                              : TextOverflow.fade,
                                          softWrap: false,
                                          maxLines: 1,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall,
                                        ),
                                        trailing: IntrinsicWidth(
                                            child: Text(
                                                enumeratedEntry.value.key,
                                                textAlign: TextAlign.right,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium)),
                                        onTap: () => _eventCarouselController
                                            .animateToPage(enumeratedEntry.key,
                                                curve: Curves.easeOutQuart)))
                                    .toList(),
                                options: CarouselOptions(
                                    aspectRatio: 1 / 5,
                                    viewportFraction: 1 / 12,
                                    scrollDirection: Axis.vertical,
                                    initialPage: index,
                                    onPageChanged: (i, _) => prefs.setString(
                                        'event', entries[i].key))),
                            GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                child: IgnorePointer(
                                    child: Center(
                                        child: Container(
                                  constraints:
                                      const BoxConstraints.tightFor(height: 40),
                                  alignment: Alignment.center,
                                  margin: const EdgeInsets.only(top: 10),
                                  color: Colors.grey.withAlpha(100),
                                ))))
                          ]);
                    })))
      ]);
}

class Configuration extends ChangeNotifier {
  static Configuration instance = Configuration();

  int _season = DateTime.now().year;

  int get season => _season;
  set season(int season) {
    _season = season;
    notifyListeners();
  }

  static String? get event =>
      prefs.containsKey("event") ? prefs.getString("event") : null;

  Future<bool> get isValid async =>
      event != null &&
      await BlueAlliance.stock
          .get((season: season, event: null, match: null)).then(
              (value) => value.containsKey(event));
}
