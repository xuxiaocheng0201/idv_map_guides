import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingState {
  final ThemeMode theme;
  final Locale? locale;

  const SettingState({
    this.theme = ThemeMode.system,
    this.locale,
  });
}

class SettingCubit extends Cubit<SettingState> {
  SettingCubit(): super(const SettingState());

  void setTheme(ThemeMode theme) {
    emit(SettingState(
      theme: theme,
      locale: state.locale,
    ));
  }

  void setLocale(Locale? locale) {
    emit(SettingState(
      theme: state.theme,
      locale: locale,
    ));
  }
}
