import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localeProvider =
    StateNotifierProvider<AppLocaleController, Locale>((ref) {
  return AppLocaleController();
});

class AppLocaleController extends StateNotifier<Locale> {
  AppLocaleController() : super(const Locale('en')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_locale');
    state = (code == 'hi') ? const Locale('hi') : const Locale('en');
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale.languageCode);
    state = locale;
  }
}
