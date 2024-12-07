import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../theme/app_theme.dart';

class ContextBuilderApp extends StatelessWidget {
  const ContextBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(  // Force LTR
      textDirection: TextDirection.ltr,
      child: MaterialApp(
        title: 'Context Builder',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
      ),
    );
  }
}
