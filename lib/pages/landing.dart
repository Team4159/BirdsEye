import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../interfaces/supabase.dart';

const deepLinkURL = "org.team4159.scouting://callback";

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text("Bird's Eye"),
      actions: [
        Text("Connection Status: ", style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(width: 10),
        Tooltip(
          message: "Supabase",
          child: FutureBuilder(
            future: SupabaseInterface.canConnect,
            builder: (context, snapshot) => CircleAvatar(
              backgroundColor: {
                null: Colors.yellow[200],
                true: Colors.green[200],
                false: Colors.red[200],
              }[snapshot.data],
              child: SvgPicture.asset('assets/images/supabase.svg', height: 18, width: 18),
            ),
          ),
        ),
        const SizedBox(width: 10),
      ],
    ),
    body: SizedBox.expand(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () => Supabase.instance.client.auth.signInWithOAuth(
              OAuthProvider.github,
              redirectTo: kIsWeb ? "${Uri.base.scheme}://${Uri.base.authority}" : deepLinkURL,
              authScreenLaunchMode: kIsWeb
                  ? LaunchMode.platformDefault
                  : LaunchMode.externalApplication,
            ),
            label: const Text('Sign In with Github', style: TextStyle(color: Colors.white)),
            icon: SizedBox.square(
              dimension: 36,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: SvgPicture.asset('assets/images/github.svg'),
              ),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Supabase.instance.client.auth.signInWithOAuth(
              OAuthProvider.google,
              redirectTo: kIsWeb ? "${Uri.base.scheme}://${Uri.base.authority}" : deepLinkURL,
              authScreenLaunchMode: kIsWeb
                  ? LaunchMode.platformDefault
                  : LaunchMode.externalApplication,
            ),
            label: const Text(
              'Sign In with Google',
              style: TextStyle(
                color: Colors.white,
                fontFamily: "Roboto",
                fontWeight: FontWeight.w500,
              ),
            ),
            icon: SvgPicture.asset('assets/images/google.svg', height: 36, width: 36),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff4285F4)),
          ),
        ],
      ),
    ),
  );
}
