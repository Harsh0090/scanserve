import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'onboarding_gate.dart';
import 'context/AuthContext.dart';
import 'context/OnboardingContext.dart';
import 'context/TrialContext.dart';

import 'signup/page.dart';

import 'login/page.dart';
import 'dashboard/layout.dart';
import 'dashboard/orders/page.dart';
import 'dashboard/OwnerSetup/page.dart';
import 'dashboard/analytics/page.dart';
import 'dashboard/profit/page.dart';
import 'dashboard/upsell/page.dart';
import 'dashboard/menu/page.dart';
import 'dashboard/pos/page.dart';
import 'dashboard/tablegenerator/page.dart';
import 'dashboard/createmanager/page.dart';
import 'dashboard/createbranch/page.dart';
import 'dashboard/IncreaseBranchLimit/page.dart';
import 'dashboard/payment_setup/page.dart';
import 'public/RestaurantMenuPage.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Dummy equivalents for other screens to make routing work
class DummyScreen extends StatelessWidget {
  final String title;
  const DummyScreen(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: Center(child: Text(title)));
}

class RootLayout extends ConsumerWidget {
  const RootLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We implicitly initialize the providers by watching or reading them if needed,
    // but in Riverpod putting `ProviderScope` at the root naturally initializes them 
    // when they are first read.
    ref.watch(authProvider);
    ref.watch(trialProvider);
    ref.watch(onboardingProvider);

    return ScreenUtilInit(
      designSize: const Size(402, 885),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp.router(
          title: 'ScanServe',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            fontFamily: 'SF Pro Display',
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF5C00)),
          ),
          routerConfig: _router,
        );
      },
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const OnboardingGate(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    ShellRoute(
      builder: (context, state, child) => DashboardLayout(child: child),
      routes: [
        GoRoute(
          path: '/dashboard/orders',
          builder: (context, state) => const OrdersPage(),
        ),
        GoRoute(
          path: '/dashboard/OwnerSetup',
          builder: (context, state) => const OwnerSetupPage(),
        ),
        GoRoute(
          path: '/dashboard/analytics',
          builder: (context, state) => const AnalyticsPage(),
        ),
        GoRoute(
          path: '/dashboard/profit',
          builder: (context, state) => const ProfitDashboardPage(),
        ),
        GoRoute(
          path: '/dashboard/upsell',
          builder: (context, state) => const UpsellPage(),
        ),
        GoRoute(
          path: '/dashboard/menu',
          builder: (context, state) => const MenuPage(),
        ),
        GoRoute(
          path: '/dashboard/pos',
          builder: (context, state) => const PosPage(),
        ),
        GoRoute(
          path: '/dashboard/tablegenerator',
          builder: (context, state) => const TableGeneratorPage(),
        ),
        GoRoute(
          path: '/dashboard/createmanager',
          builder: (context, state) => const ManagerCreatePage(),
        ),
        GoRoute(
          path: '/dashboard/createbranch',
          builder: (context, state) => const CreateBranchPage(),
        ),
        GoRoute(
          path: '/dashboard/IncreaseBranchLimit',
          builder: (context, state) => const ManagePlanPage(),
        ),
        GoRoute(
          path: '/dashboard/payment-setup',
          builder: (context, state) => const PaymentSetupPage(),
        ),
      ],
    ),
    // Dynamic Route mimicking Next.js /[id]
    GoRoute(
      path: '/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final tableNumber = state.uri.queryParameters['table'];
        return RestaurantMenuPage(restaurantId: id, tableNumber: tableNumber);
      },
    ),
  ],
);
