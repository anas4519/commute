import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/controller.dart';
import 'data/places_client.dart';
import 'data/routes_client.dart';
import 'data/storage.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await Storage.open();
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => PlacesClient()),
        ChangeNotifierProvider(create: (_) => CommuteController(storage, RoutesClient())),
      ],
      child: const CommuteApp(),
    ),
  );
}

class CommuteApp extends StatelessWidget {
  const CommuteApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Commute',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: ThemeMode.system,
    home: const HomeScreen(),
  );
}
