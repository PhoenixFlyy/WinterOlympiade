import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winter_olympiade/MainMenu.dart';

import 'TeamSelection.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkIfTeamSelected(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error'));
        } else {
          final bool teamSelected = snapshot.data ?? false;

          return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Mini Olympiade',
              theme: ThemeData.dark(
                useMaterial3: true,
              ),
              home: teamSelected ? const MainMenu() : const TeamSelection());
        }
      },
    );
  }

  Future<bool> _checkIfTeamSelected() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('selectedTeam');
  }
}
