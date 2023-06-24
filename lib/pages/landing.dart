import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
      widthFactor: 0.5,
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Card(
              child: ListTile(
                  leading: const Image(
                      image: AssetImage('assets/images/github.png')),
                  title: const Text('Sign In with Github'),
                  onTap: () => Supabase.instance.client.auth.signInWithOAuth(
                      Provider.github,
                      authScreenLaunchMode:
                          LaunchMode.externalNonBrowserApplication,
                      redirectTo: kDebugMode ? Uri.base.toString() : null)),
            ),
          ]));
}
