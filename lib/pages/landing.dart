import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(persistentFooterButtons: [
        Row(children: [
          Expanded(
            child: ListTile(
                tileColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SvgPicture.asset('assets/images/github.svg')),
                title: const Text('Sign In with Github', style: TextStyle(color: Colors.white)),
                onTap: () => Supabase.instance.client.auth.signInWithOAuth(Provider.github,
                    authScreenLaunchMode: LaunchMode.externalApplication,
                    context: context,
                    redirectTo: "${Uri.base.scheme}://${Uri.base.authority}")),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: ListTile(
                  enabled: false, // privacy policy needs to be written
                  tileColor: const Color(0xff4285F4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Padding(
                      padding: const EdgeInsets.all(8),
                      child: SvgPicture.asset('assets/images/google.svg')),
                  title: const Text('Sign In with Google',
                      style: TextStyle(
                          color: Colors.white, fontFamily: "Roboto", fontWeight: FontWeight.w500)),
                  onTap: () => Supabase.instance.client.auth.signInWithOAuth(Provider.google,
                          authScreenLaunchMode: LaunchMode.inAppWebView,
                          context: context,
                          redirectTo: "${Uri.base.scheme}://${Uri.base.authority}",
                          queryParams: {
                            // "access_type": 'offline',
                            // "prompt": 'consent',
                          })))
        ])
      ]);
}
