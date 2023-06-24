import 'package:birdseye/interfaces/bluealliance.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show prefs;

class ConfigurationPage extends StatefulWidget {
  const ConfigurationPage({super.key});

  @override
  State<StatefulWidget> createState() => ConfigurationPageState();
}

class ConfigurationPageState extends State<ConfigurationPage> {
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            height: MediaQuery.of(context).size.width / 5,
            child: FutureBuilder(
                future: Supabase.instance.client
                    .rpc("getavailableseasons")
                    .then((resp) => List<int>.from(resp)),
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
                  return CarouselSlider(
                      items: snapshot.data!
                          .map((year) => Text(year.toString(),
                              style:
                                  Theme.of(context).textTheme.headlineMedium))
                          .toList(),
                      options: CarouselOptions(
                          aspectRatio: 12 / 1,
                          viewportFraction: 1 / 3,
                          enableInfiniteScroll: false,
                          initialPage: index,
                          onPageChanged: (i, _) => Configuration
                              .instance.season = snapshot.data![i]));
                })),
        const SizedBox(height: 30),
        Expanded(
            child: FutureBuilder(
                future: BlueAlliance.tbaStock.get((
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
                      (element) => element.key == prefs.getString('event'));
                  if (!prefs.containsKey("event") || index < 0) {
                    prefs.setString("event", entries[index = 0].key);
                  }
                  return CarouselSlider(
                      items: entries
                          .map<Widget>((event) => ListTile(
                              visualDensity: VisualDensity.comfortable,
                              title: Text(
                                event.value,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                maxLines: 1,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              trailing: IntrinsicWidth(
                                  child: Text(event.key,
                                      textAlign: TextAlign.right,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium))))
                          .toList(),
                      options: CarouselOptions(
                          aspectRatio: 1 / 5,
                          viewportFraction: 0.1,
                          scrollDirection: Axis.vertical,
                          initialPage: index,
                          onPageChanged: (i, _) =>
                              prefs.setString('event', entries[i].key)));
                }))
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
}
