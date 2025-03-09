import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../interfaces/bluealliance.dart';
import '../interfaces/supabase.dart';
import '../main.dart' show prefs;
import '../utils.dart';

class ConfigurationPage extends StatelessWidget {
  final _eventCarouselController = CarouselSliderController();
  final BinaryValueNotifier _carouselProgress = BinaryValueNotifier(0);
  ConfigurationPage({super.key});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppBar(title: const Text("Configuration")),
        ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height / 8),
            child: FutureBuilder(
                future: SupabaseInterface.getAvailableSeasons(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return snapshot.hasError || (snapshot.data?.isEmpty ?? false)
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                                Icon(Icons.warning_rounded, color: Colors.red[700], size: 50),
                                Text(snapshot.error?.toString() ?? "No Data")
                              ])
                        : const LinearProgressIndicator();
                  }
                  int maybeSeason = Configuration.instance.season < 0
                      ? DateTime.now().year
                      : Configuration.instance.season;
                  int index = snapshot.data!.indexWhere((element) => element == maybeSeason);
                  if (index < 0) index = snapshot.data!.length - 1;
                  if (snapshot.data![index] != Configuration.instance.season) {
                    WidgetsBinding.instance.addPostFrameCallback(
                        (_) => Configuration.instance.season = snapshot.data![index]);
                  }
                  return Padding(
                      padding: MediaQuery.of(context).size.height > 500
                          ? const EdgeInsets.only(top: 24, bottom: 12)
                          : EdgeInsets.zero,
                      child: CarouselSlider(
                          items: snapshot.data!
                              .map((year) => Text(year.toString(),
                                  style: Theme.of(context).textTheme.headlineMedium))
                              .toList(growable: false),
                          options: CarouselOptions(
                              aspectRatio: 12 / 1,
                              viewportFraction: 1 / 3,
                              enableInfiniteScroll: false,
                              initialPage: index,
                              onScrolled: (n) => _carouselProgress.value = n == null ? 0 : n % 1,
                              onPageChanged: (i, _) =>
                                  Configuration.instance.season = snapshot.data![i])));
                })),
        Expanded(
            child: SafeArea(
                child: ListenableBuilder(
                    listenable: Configuration.instance,
                    builder: (context, child) => Configuration.instance.season < 0
                        ? const Center(child: CircularProgressIndicator())
                        : FutureBuilder(
                            future: BlueAlliance.stock
                                .get(TBAInfo(season: Configuration.instance.season)),
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
                                  snapshot.data!.entries.toList(growable: false);
                              if (entries.isEmpty) {
                                return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Icon(Icons.warning_rounded,
                                          color: Colors.yellow[600], size: 50),
                                      const SizedBox(height: 20),
                                      const Text("No Events Found")
                                    ]);
                              }
                              String maybeEvent = Configuration.event ??
                                  entries[entries.length ~/ 2].key; // TODO autofill event goes here
                              int index =
                                  entries.indexWhere((element) => element.key == maybeEvent);
                              if (index < 0) index = entries.length ~/ 2;
                              if (entries[index].key != Configuration.event) {
                                Configuration.event = entries[index].key;
                              }
                              return ValueListenableBuilder(
                                  valueListenable: _carouselProgress,
                                  builder: (context, prog, child) => AnimatedOpacity(
                                      opacity: 1 - prog, duration: Durations.short1, child: child),
                                  child: Stack(
                                      fit: StackFit.expand,
                                      alignment: Alignment.center,
                                      children: [
                                        CarouselSlider(
                                            carouselController: _eventCarouselController,
                                            items: entries
                                                .asMap()
                                                .entries
                                                .map((enumeratedEntry) => ListTile(
                                                    visualDensity:
                                                        VisualDensity.adaptivePlatformDensity,
                                                    title: Text(
                                                      enumeratedEntry.value.value,
                                                      overflow: kIsWeb
                                                          ? TextOverflow.ellipsis
                                                          : TextOverflow.fade,
                                                      softWrap: false,
                                                      maxLines: 1,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .headlineSmall!
                                                          .copyWith(fontSize: 22),
                                                    ),
                                                    trailing: IntrinsicWidth(
                                                        child: Text(enumeratedEntry.value.key,
                                                            textAlign: TextAlign.right,
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .titleMedium)),
                                                    onTap: () => _eventCarouselController
                                                        .animateToPage(enumeratedEntry.key,
                                                            curve: Curves.easeOutQuart)))
                                                .toList(growable: false),
                                            options: CarouselOptions(
                                                enableInfiniteScroll: false,
                                                aspectRatio: 1 / 5,
                                                viewportFraction: 40 /
                                                    (MediaQuery.of(context).size.height * 7 / 8),
                                                scrollDirection: Axis.vertical,
                                                initialPage: index,
                                                onPageChanged: (i, _) =>
                                                    prefs.setString('event', entries[i].key))),
                                        Center(
                                            child: GestureDetector(
                                                behavior: HitTestBehavior.translucent,
                                                child: IgnorePointer(
                                                    child: Container(
                                                        height: 35,
                                                        margin: const EdgeInsets.only(top: 12),
                                                        color: Colors.grey.withAlpha(100)))))
                                      ]));
                            }))))
      ]);
}

class Configuration extends ChangeNotifier {
  static Configuration instance = Configuration();

  int _season = -1;

  int get season => _season;

  /// Set the configuration season. UNGUARDED.
  set season(int season) {
    if (_season == season) return;
    _season = season;
    notifyListeners();
  }

  Future<bool> setSeason(int season) async {
    if (!(await SupabaseInterface.getAvailableSeasons()).contains(season)) return false;
    if (_season == season) return true;
    _season = season;
    notifyListeners();
    return true;
  }

  static String? get event => prefs.containsKey("event") ? prefs.getString("event") : null;
  static set event(String? e) => e == null ? prefs.remove("event") : prefs.setString("event", e);

  Future<bool> get isValid async =>
      season >= 0 &&
      event != null &&
      await BlueAlliance.stock
          .get(TBAInfo(season: season))
          .then((value) => value.containsKey(event));
}
