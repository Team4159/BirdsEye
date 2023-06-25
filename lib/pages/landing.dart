import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LandingPage extends StatelessWidget {
  // TODO: Flesh out nice intro landing page
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
      widthFactor: 0.4,
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Card(
              child: ListTile(
                  leading: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Image(
                          isAntiAlias: true,
                          image: AssetImage('assets/images/github.png'))),
                  title: const Text('Sign In with Github'),
                  onTap: () => Supabase.instance.client.auth.signInWithOAuth(
                      Provider.github,
                      authScreenLaunchMode: LaunchMode.platformDefault,
                      redirectTo: kDebugMode
                          ? "${Uri.base.scheme}://${Uri.base.authority}"
                          : null)),
            )
          ]));
}
