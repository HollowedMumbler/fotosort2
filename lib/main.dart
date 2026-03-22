import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const FotoSort());
}

class FotoSort extends StatelessWidget {
  const FotoSort({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FotoSort',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: FotoColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: FotoColors.textPrimary),
        appBarTheme: const AppBarTheme(
          backgroundColor: FotoColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: FotoText.title,
          iconTheme: IconThemeData(color: FotoColors.textPrimary, size: 22),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
