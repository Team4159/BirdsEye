import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LandingPage extends StatelessWidget {
  LandingPage({super.key});
  final FocusNode googleFocus = FocusNode();

  @override
  Widget build(BuildContext context) => Scaffold(persistentFooterButtons: [
        Card(
          color: Colors.black,
          child: ListTile(
              leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SvgPicture.asset('assets/images/github.svg')),
              title: const Text('Sign In with Github', style: TextStyle(color: Colors.white)),
              onTap: () => Supabase.instance.client.auth.signInWithOAuth(Provider.github,
                  authScreenLaunchMode: LaunchMode.externalApplication,
                  redirectTo: "${Uri.base.scheme}://${Uri.base.authority}")),
        ),
        // Card(
        //     color: const Color(0xff4285F4),
        //     child: ListTile(
        //         focusNode: googleFocus,
        //         leading: Padding(
        //             padding: const EdgeInsets.all(8),
        //             child: googleFocus.hasFocus
        //                 ? SvgPicture.asset('assets/images/google_focus.svg')
        //                 : SvgPicture.asset('assets/images/google_normal.svg')),
        //         title: const Text('Sign In with Google',
        //             style: TextStyle(
        //                 color: Colors.white, fontFamily: "Roboto", fontWeight: FontWeight.w500)),
        //         onTap: () => Supabase.instance.client.auth.signInWithOAuth(Provider.google,
        //             authScreenLaunchMode: LaunchMode.externalApplication,
        //             redirectTo: "${Uri.base.scheme}://${Uri.base.authority}")))
      ]);
}
