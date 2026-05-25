import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/settings_model.dart';
import '../../data/settings_repository.dart';

// Events
abstract class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => [];
}

class LoadSettingsEvent extends SettingsEvent {
  const LoadSettingsEvent();
}

class UpdateSettingsEvent extends SettingsEvent {
  final AppSettings settings;
  const UpdateSettingsEvent(this.settings);
  @override
  List<Object?> get props => [settings];
}

// States
abstract class SettingsState extends Equatable {
  const SettingsState();
  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

class SettingsLoaded extends SettingsState {
  final AppSettings settings;
  const SettingsLoaded(this.settings);
  @override
  List<Object?> get props => [settings];
}

// Bloc
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository _repository;

  SettingsBloc(this._repository) : super(const SettingsInitial()) {
    on<LoadSettingsEvent>(_onLoad);
    on<UpdateSettingsEvent>(_onUpdate);
  }

  Future<void> _onLoad(
      LoadSettingsEvent event, Emitter<SettingsState> emit) async {
    final settings = await _repository.getSettings();
    emit(SettingsLoaded(settings));
  }

  Future<void> _onUpdate(
      UpdateSettingsEvent event, Emitter<SettingsState> emit) async {
    await _repository.saveSettings(event.settings);
    emit(SettingsLoaded(event.settings));
  }
}
