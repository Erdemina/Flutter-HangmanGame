import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'home_screen.dart';
import 'user_session.dart';

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userInput = _usernameController.text.trim();
      final password = _passwordController.text;

      final loginUri = Uri.parse(
          "https://5wcorlr6ic.execute-api.eu-north-1.amazonaws.com/v2/login?user_input=$userInput&password=$password");

      final loginRes = await http.get(loginUri);

      if (!mounted) return;

      if (loginRes.statusCode == 200) {
        final loginData = json.decode(loginRes.body);
        final userId = loginData['userId'];

        final fetchUri = Uri.parse(
            "https://5wcorlr6ic.execute-api.eu-north-1.amazonaws.com/v2/fetchUser?userId=$userId");

        final fetchRes = await http.get(fetchUri);

        if (!mounted) return;

        if (fetchRes.statusCode == 200) {
          final userData = json.decode(fetchRes.body);

          await UserSession.saveUser(
            username: userData['username'] ?? 'Unknown',
            userId: userId,
            trophies: (userData['trophies'] ?? 0).toInt(),
            gladiator: userData['gladiator'] ?? 'assets/P1.png',
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                username: UserSession.username ?? '',
                trophies: UserSession.trophies,
                gladiator: UserSession.gladiator ?? 'assets/P1.png',
              ),
            ),
            (route) => false,
          );
        } else {
          throw Exception("Kullanıcı bilgisi alınamadı");
        }
      } else if (loginRes.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Geçersiz giriş bilgisi")),
        );
      } else {
        throw Exception("Sunucu hatası: ${loginRes.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text("Login"),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "Email veya Username",
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Lütfen kullanıcı adı veya email girin';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: "Password",
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Lütfen şifrenizi girin';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Login"),
        ),
      ],
    );
  }
}
