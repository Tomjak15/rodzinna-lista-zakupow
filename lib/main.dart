import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_state.dart';
import 'data/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await LocalStore.create();
  final appState = AppState(store: store);
  await appState.initialize();

  runApp(RodzinnaListaApp(appState: appState));
}
