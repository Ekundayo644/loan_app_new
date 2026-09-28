import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:loan_app_new/services/settings_service.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  double? _interestRate;
  bool _isLoading = false;
  String? _error;

  double? get interestRate => _interestRate;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ============= SAFE NOTIFY =============
  void _safeNotify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    _safeNotify();
  }

  Future<void> fetchInterestRate() async {
    _setLoading(true);
    try {
      _interestRate = await _settingsService.getInterestRate();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateInterestRate(double newRate) async {
    _setLoading(true);
    try {
      await _settingsService.updateInterestRate(newRate);
      _interestRate = newRate;
      _error = null;
      _safeNotify();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }
}