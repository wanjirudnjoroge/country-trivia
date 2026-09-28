import 'package:flutter/material.dart';

import 'core/app_routes.dart';
import 'core/app_theme.dart';
import 'screens/quiz_screen.dart';

/// Root widget: Material 3 theming and routing.
class CountryTriviaApp extends StatelessWidget {
  const CountryTriviaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Country Trivia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.quiz,
      routes: <String, WidgetBuilder>{
        AppRoutes.quiz: (_) => const QuizScreen(),
      },
    );
  }
}
