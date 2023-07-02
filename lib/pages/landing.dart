import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(persistentFooterButtons: [
        Card(
          color: Colors.black,
          child: ListTile(
              leading: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Image(
                      isAntiAlias: true,
                      image: AssetImage('assets/images/github.png'))),
              title: const Text('Sign In with Github',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Supabase.instance.client.auth.signInWithOAuth(
                  Provider.github,
                  authScreenLaunchMode: LaunchMode.platformDefault,
                  redirectTo: "${Uri.base.scheme}://${Uri.base.authority}")),
        )
      ]);
}
