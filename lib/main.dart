import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'core/log.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/controller.dart';
import 'data/places_client.dart';
import 'data/routes_client.dart';
import 'data/storage.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final storage = await Storage.open();
  try {
    final dir = await getApplicationDocumentsDirectory();
    await AppLog.I.attach(File('${dir.path}/debug.log'));
  } catch (_) {}
  AppLog.d('app', 'start');
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
    themeMode: context.select<CommuteController, ThemeMode>((c) => c.themeMode),
    home: const HomeScreen(),
  );
}
