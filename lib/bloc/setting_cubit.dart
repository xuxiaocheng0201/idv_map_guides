import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'setting_cubit.freezed.dart';

@freezed
abstract class SettingState with _$SettingState {
  const SettingState._();
  const factory SettingState({
    @Default(ThemeMode.system) ThemeMode theme,
    Locale? locale,
  }) = _SettingState;
}

class SettingCubit extends Cubit<SettingState> {
  SettingCubit(): super(const SettingState());

  void setTheme(ThemeMode theme) {
    emit(state.copyWith(theme: theme));
  }

  void setLocale(Locale? locale) {
    emit(state.copyWith(locale: locale));
  }
}
