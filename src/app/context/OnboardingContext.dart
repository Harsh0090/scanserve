import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingState {
  final bool showSuccessModal;
  final String? newRestaurantId;
  final int trialDaysLeft;

  OnboardingState({
    required this.showSuccessModal,
    this.newRestaurantId,
    required this.trialDaysLeft,
  });

  OnboardingState copyWith({
    bool? showSuccessModal,
    String? newRestaurantId,
    int? trialDaysLeft,
  }) {
    return OnboardingState(
      showSuccessModal: showSuccessModal ?? this.showSuccessModal,
      newRestaurantId: newRestaurantId ?? this.newRestaurantId,
      trialDaysLeft: trialDaysLeft ?? this.trialDaysLeft,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    _loadTrialDays();
    return OnboardingState(showSuccessModal: false, trialDaysLeft: 7);
  }

  Future<void> _loadTrialDays() async {
    final prefs = await SharedPreferences.getInstance();
    final signupDateStr = prefs.getString('signupDate');
    if (signupDateStr != null) {
      final signupDate = DateTime.parse(signupDateStr);
      final diff = DateTime.now().difference(signupDate).inDays;
      final daysLeft = 7 - diff;
      state = state.copyWith(trialDaysLeft: daysLeft > 0 ? daysLeft : 0);
    }
  }

  void triggerSuccess(String id) {
    state = state.copyWith(newRestaurantId: id, showSuccessModal: true);
  }

  void closeSuccess() {
    state = state.copyWith(showSuccessModal: false);
  }

  void setTrialDaysLeft(int days) {
    state = state.copyWith(trialDaysLeft: days);
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, OnboardingState>(OnboardingNotifier.new);
