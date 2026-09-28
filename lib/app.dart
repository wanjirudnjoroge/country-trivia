import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_routes.dart';
import 'core/app_theme.dart';
import 'data/country_repository.dart';
import 'screens/quiz_screen.dart';
import 'viewmodels/quiz_view_model.dart';

/// Root widget: dependency graph, Material 3 theming and routing.
///
/// [repository] is injected so tests and the debug build can substitute a
/// different country source without touching the widget tree.
class CountryTriviaApp extends StatelessWidget {
  const CountryTriviaApp({super.key, required this.repository});

  final CountryRepository repository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<CountryRepository>.value(value: repository),
        ChangeNotifierProvider<QuizViewModel>(
          create: (BuildContext context) =>
              QuizViewModel(context.read<CountryRepository>())..startNewGame(),
        ),
      ],
      child: MaterialApp(
        title: 'Country Trivia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        initialRoute: AppRoutes.quiz,
        routes: <String, WidgetBuilder>{
          AppRoutes.quiz: (_) => const QuizScreen(),
        },
      ),
    );
  }
}
