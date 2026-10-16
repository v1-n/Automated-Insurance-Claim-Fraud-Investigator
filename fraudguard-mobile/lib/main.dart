import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/admin_claims_provider.dart';
import 'providers/admin_dashboard_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/customer_claims_provider.dart';
import 'providers/investigator_claims_provider.dart';
import 'providers/policy_provider.dart';
import 'providers/realtime_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/admin/admin_claims_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_policies_screen.dart';
import 'screens/admin/admin_workload_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/common/notifications_screen.dart';
import 'screens/common/profile_screen.dart';
import 'screens/customer/customer_dashboard_screen.dart';
import 'screens/customer/my_claims_screen.dart';
import 'screens/customer/my_policies_screen.dart';
import 'screens/customer/submit_claim_screen.dart';
import 'screens/investigator/investigator_claims_screen.dart';
import 'screens/investigator/investigator_dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => RealtimeProvider()),
        ChangeNotifierProvider(create: (_) => AdminDashboardProvider()),
        ChangeNotifierProvider(create: (_) => AdminClaimsProvider()),
        ChangeNotifierProvider(create: (_) => CustomerClaimsProvider()),
        ChangeNotifierProvider(create: (_) => InvestigatorClaimsProvider()),
        ChangeNotifierProvider(create: (_) => PolicyProvider()),
      ],
      child: const FraudGuardApp(),
    ),
  );
}

class FraudGuardApp extends StatelessWidget {
  const FraudGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'FraudGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isInitialized) {
      return const _SplashScreen();
    }

    if (!authProvider.isAuthenticated) {
      return const LoginScreen();
    }

    return const MainNavigationShell();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Shield logo in blue rounded square using our generated app_logo.png
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withAlpha(90),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'FraudGuard',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Automated Claim & Fraud\nInvestigation Platform',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            // Animated three staggered bouncing dots
            const _ThreeBouncingDots(),
          ],
        ),
      ),
    );
  }
}

class _ThreeBouncingDots extends StatefulWidget {
  const _ThreeBouncingDots();

  @override
  State<_ThreeBouncingDots> createState() => _ThreeBouncingDotsState();
}

class _ThreeBouncingDotsState extends State<_ThreeBouncingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final delay = index * 0.4;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final value = (sin((_controller.value * 2 * pi) - delay) + 1) / 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 10,
              height: 10,
              transform: Matrix4.translationValues(0, -value * 12, 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryBlue.withAlpha((255 * (0.3 + 0.7 * value)).toInt()),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withAlpha((255 * 0.4 * value).toInt()),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    List<Widget> screens = [];
    List<BottomNavigationBarItem> navItems = [];

    if (authProvider.isAdmin) {
      screens = const [
        AdminDashboardScreen(),
        AdminClaimsScreen(),
        AdminPoliciesScreen(),
        AdminWorkloadScreen(),
        ProfileScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.gavel_outlined), activeIcon: Icon(Icons.gavel), label: 'Claims'),
        BottomNavigationBarItem(icon: Icon(Icons.policy_outlined), activeIcon: Icon(Icons.policy), label: 'Policies'),
        BottomNavigationBarItem(icon: Icon(Icons.badge_outlined), activeIcon: Icon(Icons.badge), label: 'Workload'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outlined), activeIcon: Icon(Icons.person), label: 'Profile'),
      ];
    } else if (authProvider.isInvestigator) {
      screens = [
        InvestigatorDashboardScreen(onSeeAll: () {
          setState(() {
            _selectedIndex = 1;
          });
        }),
        const InvestigatorClaimsScreen(),
        const NotificationsScreen(),
        const ProfileScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.folder_special_outlined), activeIcon: Icon(Icons.folder_special), label: 'Cases'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications), label: 'Alerts'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outlined), activeIcon: Icon(Icons.person), label: 'Profile'),
      ];
    } else {
      // CUSTOMER / USER
      screens = const [
        CustomerDashboardScreen(),
        MyPoliciesScreen(),
        MyClaimsScreen(),
        SubmitClaimScreen(),
        ProfileScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.security_outlined), activeIcon: Icon(Icons.security), label: 'Policies'),
        BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'Claims'),
        BottomNavigationBarItem(icon: Icon(Icons.post_add_outlined), activeIcon: Icon(Icons.note_add), label: 'File'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outlined), activeIcon: Icon(Icons.person), label: 'Profile'),
      ];
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: isDark ? Colors.grey[400] : const Color(0xFF64748B),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: navItems,
      ),
    );
  }
}
