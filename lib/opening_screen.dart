import 'package:flutter/material.dart';
import 'login_dialog.dart';
import 'signup_dialog.dart';
import 'user_session.dart';

class OpeningScreen extends StatelessWidget {
  const OpeningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Arka plan
          Positioned.fill(
            child: Image.asset(
              'assets/openingscreen.webp',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Theme.of(context).colorScheme.background,
                );
              },
            ),
          ),

          // İçerik
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/LoginFont.png',
                    width: 200,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text(
                        'Hangman Game',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 50),

                  // Giriş Yap Butonu
                  ElevatedButton(
                    onPressed: () async {
                      final result = await showDialog(
                        context: context,
                        builder: (context) => const LoginDialog(),
                      );
                      if (result == true && UserSession.isLoggedIn) {
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/home');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 50,
                        vertical: 15,
                      ),
                    ),
                    child: const Text('Giriş Yap'),
                  ),
                  const SizedBox(height: 20),

                  // Kayıt Ol Butonu
                  ElevatedButton(
                    onPressed: () async {
                      final result = await showDialog(
                        context: context,
                        builder: (context) => const SignupDialog(),
                      );
                      if (result == true && UserSession.isLoggedIn) {
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/home');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 50,
                        vertical: 15,
                      ),
                    ),
                    child: const Text('Kayıt Ol'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
