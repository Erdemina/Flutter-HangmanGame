import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserSession {
  static String? _username;
  static int _trophies = 0;
  static String? _gladiator;
  static bool _isLoggedIn = false;
  static String? _userId;

  static String? get username => _username;
  static int get trophies => _trophies;
  static String? get gladiator => _gladiator;
  static bool get isLoggedIn => _isLoggedIn;
  static String? get userId => _userId;

  static Future<void> loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _username = prefs.getString('username');
      _trophies = prefs.getInt('trophies') ?? 0;
      _gladiator = prefs.getString('gladiator');
      _userId = prefs.getString('userId');
      _isLoggedIn = _username != null && _userId != null;
    } catch (e) {
      print('Error loading user session: $e');
      _resetSession();
    }
  }

  static Future<void> saveUser({
    required String username,
    required String userId,
    int trophies = 0,
    String? gladiator,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      await prefs.setString('userId', userId);
      await prefs.setInt('trophies', trophies);
      if (gladiator != null) {
        await prefs.setString('gladiator', gladiator);
      }

      _username = username;
      _userId = userId;
      _trophies = trophies;
      _gladiator = gladiator;
      _isLoggedIn = true;
    } catch (e) {
      print('Error saving user session: $e');
      throw Exception('Failed to save user session');
    }
  }

  static Future<void> updateTrophies(int newTrophies) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('trophies', newTrophies);
      _trophies = newTrophies;
    } catch (e) {
      print('Error updating trophies: $e');
      throw Exception('Failed to update trophies');
    }
  }

  static Future<void> updateGladiator(String newGladiator) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gladiator', newGladiator);
      _gladiator = newGladiator;
    } catch (e) {
      print('Error updating gladiator: $e');
      throw Exception('Failed to update gladiator');
    }
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _resetSession();
    } catch (e) {
      print('Error during logout: $e');
      throw Exception('Failed to logout');
    }
  }

  static void _resetSession() {
    _username = null;
    _trophies = 0;
    _gladiator = null;
    _isLoggedIn = false;
    _userId = null;
  }
}
