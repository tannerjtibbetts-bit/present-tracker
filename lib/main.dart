import 'package:flutter/material.dart';

import 'data/store.dart';
import 'screens/home_screen.dart';
import 'ui/themes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStore.open();
  runApp(const PresentTrackerApp());
}

class PresentTrackerApp extends StatelessWidget {
  const PresentTrackerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Present Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: HomeColors.gold).copyWith(primary: HomeColors.accent, surface: Colors.white),
          scaffoldBackgroundColor: HomeColors.bg,
        ),
        home: const HomeScreen(),
      );
}
