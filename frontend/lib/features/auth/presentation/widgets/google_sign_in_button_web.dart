import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

class GoogleSignInWebButton extends StatelessWidget {
  const GoogleSignInWebButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: google_web.renderButton(
        configuration: google_web.GSIButtonConfiguration(
          theme: google_web.GSIButtonTheme.outline,
          shape: google_web.GSIButtonShape.rectangular,
          size: google_web.GSIButtonSize.large,
          text: google_web.GSIButtonText.continueWith,
        ),
      ),
    );
  }
}
