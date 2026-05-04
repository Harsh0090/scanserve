import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'context/AuthContext.dart';
import 'signup/page.dart';
import 'home/logged_in_home.dart';

/// Replaces the old landing page as the '/' route.
/// - Loading  -> orange spinner
/// - Logged in -> LoggedInHomePage (analytics dashboard)
/// - Not logged in -> SignupPage directly
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.loading2) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5C00)),
        ),
      );
    }

    if (authState.user != null) {
      return const LoggedInHomePage();
    }

    return const SignupPage();
  }
}
