import 'package:birdseye/interfaces/supabase.dart' show SupabaseInterface;
import 'package:birdseye/routing.dart' show MetadataRoute, appRouter;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

class UserMetadataWrapper extends StatefulWidget {
  final Widget child;
  const UserMetadataWrapper({super.key, required this.child});

  @override
  State<UserMetadataWrapper> createState() => _UserMetadataWrapperState();
}

class _UserMetadataWrapperState extends State<UserMetadataWrapper> {
  String? _id;
  ({String name, int team})? _info;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  /// Begin listening for the initial login event
  void _subscribe() => Supabase.instance.client.auth.onAuthStateChange
      .firstWhere((event) => event.session != null)
      .then((auth) {
        _id = auth.session!.user.id;
        return fetch();
      })
      .then((_) => appRouter.go(const MetadataRoute(redir: true).location));

  Future<void> fetch() {
    return Supabase.instance.client
        .from("users")
        .select('name, team')
        .eq('id', _id!)
        .maybeSingle()
        .then((resp) {
          if (resp == null) throw Exception("No User Found");
          if (_info?.name == resp['name'] && _info?.team == resp['team']) return;
          setState(() => _info = (name: resp['name'], team: resp['team']));
        })
        .onError<Object>((e, _) {
          setState(() => _info = null);
          throw e;
        });
  }

  Future<void> update(String name, int team) => Supabase.instance.client
      .from("users")
      .update({"name": name, "team": team})
      .eq("id", _id!)
      .select()
      .single()
      .then((resp) => setState(() => _info = (name: resp['name'], team: resp['team'])));

  Future<void> signOut() async {
    await SupabaseInterface.clearSession();
    await Supabase.instance.client.auth.signOut();
    await Supabase.instance.client.auth.onAuthStateChange.firstWhere(
      (event) => event.session == null,
    );
    setState(() => _id = _info = null);
    _subscribe(); // ready the app for the next sign in
  }

  @override
  Widget build(BuildContext context) =>
      UserMetadata(id: _id, info: _info, update: update, signOut: signOut, child: widget.child);
}

class UserMetadata extends InheritedWidget with Diagnosticable {
  final String? id;
  final ({String name, int team})? _info;
  final Future<void> Function(String name, int team) update;
  final Future<void> Function() signOut;

  bool get isSignedIn => id != null;
  bool get hasMeta => _info != null;
  String? get name => _info?.name;
  int? get team => _info?.team;

  const UserMetadata({
    super.key,
    required this.id,
    ({String name, int team})? info,
    required this.update,
    required this.signOut,
    required super.child,
  }) : _info = info;

  @override
  bool updateShouldNotify(covariant UserMetadata old) {
    return old.id != id || old._info != _info;
  }

  static UserMetadata of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<UserMetadata>();

    if (widget == null) {
      throw FlutterError(
        'UserMetadata.of() was called with a context that does not contain a UserMetadata widget.\n'
        'The context used was:\n'
        '  $context',
      );
    }

    return widget;
  }

  static UserMetadata? read(BuildContext context) =>
      context.getElementForInheritedWidgetOfExactType<UserMetadata>()?.widget as UserMetadata?;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties.add(StringProperty("id", id));
    properties.add(StringProperty("name", name));
    properties.add(IntProperty("team", team));
    super.debugFillProperties(properties);
  }
}
