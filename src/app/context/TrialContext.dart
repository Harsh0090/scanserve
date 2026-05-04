import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'AuthContext.dart';
import '../../utils/apiClient.dart';

class TrialState {
  final bool isTrialExpired;
  TrialState(this.isTrialExpired);
}

class TrialNotifier extends Notifier<TrialState> {
  StreamSubscription? _subscription;

  @override
  TrialState build() {
    // React to AuthState changes
    final authState = ref.watch(authProvider);
    final user = authState.user;
    
    // Listen to API-level events (equivalent to window.addEventListener("TRIAL_EXPIRED"))
    _subscription?.cancel();
    _subscription = trialEventController.stream.listen((event) {
      state = TrialState(true);
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    if (user != null) {
      if (user['subscriptionStatus'] == 'EXPIRED' || user['subscriptionStatus'] == 'SUSPENDED') {
        return TrialState(true);
      } else {
        return TrialState(false);
      }
    }
    
    return TrialState(false);
  }

  void triggerTrialExpired() {
    state = TrialState(true);
  }
}

final trialProvider = NotifierProvider<TrialNotifier, TrialState>(TrialNotifier.new);
