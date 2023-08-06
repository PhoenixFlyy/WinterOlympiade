import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winter_olympiade/Dartsrechner.dart';
import 'package:winter_olympiade/Laufplan.dart';
import 'package:winter_olympiade/Regeln.dart';
import 'package:winter_olympiade/Schachuhr.dart';
import 'package:winter_olympiade/TeamSelection.dart';
import 'dart:async';
import 'package:winter_olympiade/main.dart'; //brauchen wir das?

class TeamDetails {
  final String selectedTeam;
  final String opponent;
  final int round;
  final int discipline;

  TeamDetails({
    required this.selectedTeam,
    required this.opponent,
    required this.round,
    required this.discipline,
  });
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkIfTeamSelected(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Center(child: Text('Error'));
        } else {
          final bool teamSelected = snapshot.data ?? false;

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Mini Olympiade',
            theme: ThemeData.dark(
              useMaterial3: true,
            ),
            home: teamSelected ? mainMenu() : TeamSelection(),
          );
        }
      },
    );
  }

  Future<bool> _checkIfTeamSelected() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('selectedTeam');
  }
}

class mainMenu extends StatefulWidget {
  const mainMenu({super.key});

  @override
  State<mainMenu> createState() => _mainMenuState();
}

class _mainMenuState extends State<mainMenu> {
  late Timer _timer;
  String match = ''; // Hier definiere ich 'match' als Instanzvariable.

  int maxtime = 240;
  DateTime? eventStartTime;

  int roundTime = 10; // Round time in minutes
  final _roundTimeController = TextEditingController();

  bool eventStarted = false;
  String selectedTeam = '';

  TimeOfDay _eventStartTime = TimeOfDay(hour: 0, minute: 0);

  late Future<TeamDetails> futureTeamDetails;

  final _maxTimeController = TextEditingController();
  final _eventStartTimeController = TextEditingController();

  List<List<String>> pairings = [
    // ... Your existing pairings list ...
  ];

  void _startEvent() {
    eventStartTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      _eventStartTime.hour,
      _eventStartTime.minute,
    );
    setState(() {
      eventStarted = true;
    });
  }

  int currentRound = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance?.addPostFrameCallback((_) async {
      await _loadSelectedTeam();

      if (selectedTeam.isNotEmpty &&
          currentRound > 0 &&
          currentRound <= pairings.length) {
        List<String> roundPairings = pairings[currentRound - 1];
        for (String pairing in roundPairings) {
          List<String> teams = pairing.split('-');
          if (teams.contains(selectedTeam.split(' ')[1])) {
            match = pairing;
            break;
          }
        }
      }
    });

    _timer = Timer.periodic(
      Duration(seconds: 1),
      (timer) {
        if (this.mounted) {
          setState(() {
            if (eventStarted) {
              int elapsedSeconds = DateTime.now()
                  .difference(eventStartTime ?? DateTime.now())
                  .inSeconds;
              int newCurrentRound = (elapsedSeconds / (roundTime * 60)).ceil();

              if (newCurrentRound != currentRound) {
                currentRound = newCurrentRound;

                if (selectedTeam.isNotEmpty &&
                    currentRound > 0 &&
                    currentRound <= pairings.length) {
                  List<String> roundPairings = pairings[currentRound - 1];
                  for (String pairing in roundPairings) {
                    List<String> teams = pairing.split('-');
                    if (teams.contains(selectedTeam.split(' ')[1])) {
                      match = pairing;
                      break;
                    }
                  }
                }
              }
            }
          });
        }
      },
    );

    WidgetsBinding.instance?.addPostFrameCallback((_) async {
      await _loadSelectedTeam();
      futureTeamDetails = getTeamDetails();
    });
  }

  Future<void> _loadSelectedTeam() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String storedSelectedTeam = prefs.getString('selectedTeam') ?? '';
    if (this.mounted) {
      setState(() {
        selectedTeam = storedSelectedTeam;
      });
    }
  }

  Future<TeamDetails> getTeamDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String selectedTeam = prefs.getString('selectedTeam') ?? '';
    String opponent = prefs.getString('opponent') ?? '';
    int round = prefs.getInt('round') ?? 0;
    int discipline = prefs.getInt('discipline') ?? 0;

    return TeamDetails(
      selectedTeam: selectedTeam,
      opponent: opponent,
      round: round,
      discipline: discipline,
    );
  }

  @override
  void dispose() {
    _maxTimeController.dispose();
    _roundTimeController.dispose();
    _eventStartTimeController.dispose();
    _timer.cancel(); // Cancel the timer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate current round
    int elapsedSeconds =
        DateTime.now().difference(eventStartTime ?? DateTime.now()).inSeconds;
    int currentRound = (elapsedSeconds / (roundTime * 60)).ceil();

    // Calculate remaining time in the current round
    int elapsedSecondsInCurrentRound = elapsedSeconds % (roundTime * 60);
    int remainingSecondsInCurrentRound =
        roundTime * 60 - elapsedSecondsInCurrentRound;

    String remainingTimeInCurrentRound =
        Duration(seconds: remainingSecondsInCurrentRound)
            .toString()
            .split('.')
            .first
            .padLeft(8, "0");

    // Determine team's match
    String match = '';
    if (selectedTeam.isNotEmpty &&
        currentRound > 0 &&
        currentRound <= pairings.length) {
      List<String> roundPairings = pairings[currentRound - 1];
      for (String pairing in roundPairings) {
        List<String> teams = pairing.split('-');
        if (teams.contains(selectedTeam.split(' ')[1])) {
          match = pairing;
          break;
        }
      }
    }

    String appBarTitle = 'Olympiade';
    if (selectedTeam.isNotEmpty) {
      appBarTitle += ' - $selectedTeam';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              _openSettings();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.timer),
              SizedBox(width: 8.0),
              Text('Zeit: $remainingTimeInCurrentRound'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.circle),
              SizedBox(width: 8.0),
              Text('Runde $currentRound'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.people),
              SizedBox(width: 8.0),
              Text('Team\'s Match: $match'), // Use match variable here
            ],
          ),
          Spacer(),
          Container(
            height: MediaQuery.of(context).size.height / 12,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16.0),
              ),
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => DartsRechner()));
              },
              child: Text(
                'Dartsrechner',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ),
          SizedBox(height: 16.0),
          Container(
            height: MediaQuery.of(context).size.height / 12,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16.0),
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SchachUhr(
                              maxtime: maxtime,
                            )));
              },
              child: Text(
                'Schachuhr',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ),
          SizedBox(height: 16.0),
          Container(
            height: MediaQuery.of(context).size.height / 12,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16.0),
              ),
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => RulesScreen()));
              },
              child: Text(
                'Regeln',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ),
          SizedBox(height: 16.0),
          ElevatedButton(
            onPressed: () {
              _startEvent();
            },
            child: Text(
                eventStarted ? 'Das Event ist im Gange...' : 'Event Starten'),
          ),
          SizedBox(height: 16.0),
        ],
      ),
    );
  }

  void _openSettings() {
    _maxTimeController.text = maxtime.toString();
    _roundTimeController.text = roundTime.toString();

    // _roundTimeController.text = roundTime.toString(); // ChatGPt ist sich uneins, ob man das hier braucht

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _maxTimeController,
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(labelText: "Schachuhr Zeit in Sekunden"),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    setState(() {
                      maxtime = int.tryParse(value) ?? maxtime;
                    });
                  },
                ),
                TextField(
                  // New TextField for round time
                  controller: _roundTimeController,
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(labelText: "Rundenzeit in Minuten"),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    setState(() {
                      roundTime = int.tryParse(value) ?? roundTime;
                    });
                  },
                ),
                SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => Laufplan()));
                  },
                  child: Text('Laufplan �ffnen'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (context) => TeamSelection(),
                    ));
                  },
                  child: Text('Teamauswahl'),
                ),
                SizedBox(height: 16.0),
                TimePickerWidget(
                  initialTime: _eventStartTime,
                  onTimeSelected: (selectedTime) {
                    setState(() {
                      _eventStartTime = selectedTime;
                    });
                  },
                ),
                SizedBox(height: 16.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TimePickerWidget extends StatefulWidget {
  final TimeOfDay initialTime;
  final Function(TimeOfDay) onTimeSelected;

  const TimePickerWidget({
    Key? key,
    required this.initialTime,
    required this.onTimeSelected,
  }) : super(key: key);

  @override
  _TimePickerWidgetState createState() => _TimePickerWidgetState();
}

class _TimePickerWidgetState extends State<TimePickerWidget> {
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Event Startzeit: ${_selectedTime.format(context)}'),
        IconButton(
          icon: Icon(Icons.access_time),
          onPressed: () async {
            final TimeOfDay? pickedTime = await showTimePicker(
              context: context,
              initialTime: _selectedTime,
            );

            if (pickedTime != null) {
              setState(() {
                _selectedTime = pickedTime;
              });
              widget.onTimeSelected(pickedTime);
            }
          },
        ),
      ],
    );
  }
}
