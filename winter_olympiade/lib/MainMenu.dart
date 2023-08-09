import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winter_olympiade/uploadresults.dart';
import 'package:winter_olympiade/utils/DateTimeUtils.dart';
import 'package:winter_olympiade/utils/GetMatchDetails.dart';
import 'package:winter_olympiade/utils/MatchDetails.dart';

import 'Dartsrechner.dart';
import 'Regeln.dart';
import 'Schachuhr.dart';
import 'SchedulePage.dart';
import 'TeamSelection.dart';





class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  late Timer _timer;
  String currentMatchUpText = '';
  String nextMatchUpText = '';

  Duration maxChessTime = const Duration(minutes: 4);
  Duration roundTimeDuration = const Duration(minutes: 10);

  final _roundTimeController = TextEditingController();
  final _maxTimeController = TextEditingController();
  final _eventStartTimeController = TextEditingController();

  int currentRound = 0;
  bool isPaused = true;
  int pauseTimeInSeconds = 0;

  int selectedTeam = 0;
  String selectedTeamName = "";

  DateTime _eventStartTime = DateTime(2023, 9, 5);

  final DatabaseReference _databaseTime =
      FirebaseDatabase.instance.ref('/time');

  void _activateDatabaseTimeListener() {
    _databaseTime.child("isPaused").onValue.listen((event) {
      final bool streamIsPaused =
          event.snapshot.value.toString().toLowerCase() == 'true';
      setState(() {
        isPaused = streamIsPaused;
      });
    });
    _databaseTime.child("pauseTime").onValue.listen((event) {
      final int streamPauseTime =
          int.tryParse(event.snapshot.value.toString()) ?? 0;
      setState(() {
        pauseTimeInSeconds = streamPauseTime;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSelectedTeam();
    _setUpTimer();
    _loadData();
    _activateDatabaseTimeListener();
  }

  void _loadData() async {
    await getOlympiadeStartDateTime().then((value) {
      _eventStartTime = value;
    });
  }

  void _setUpTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), _updateTimerCallback);
  }

  void _updateTimerCallback(Timer timer) {
    if (!isPaused) {
      _updateCurrentRound();
      _updateMatchAndDiscipline();
    }
  }

  void _updateCurrentRound() {
    int newCurrentRound = calculateCurrentRoundWithDateTime();

    if (newCurrentRound != currentRound) {
      setState(() {
        currentRound = newCurrentRound;
      });
    }
  }

  void _updateMatchAndDiscipline() {
    if (currentRound > 0 && currentRound <= pairings.length) {
      var opponentTeamNumber =
          getOpponentTeamNumber(currentRound, selectedTeam);
      var nextOpponentTeamNumber =
          getOpponentTeamNumber(currentRound + 1, selectedTeam);
      var disciplineName = getDisciplineName(currentRound, selectedTeam);
      var nextDisciplineName =
          getDisciplineName(currentRound + 1, selectedTeam);
      var startTeam = isStartingTeam(currentRound, selectedTeam)
          ? "Beginner: Team $selectedTeam"
          : "Beginner: Team $opponentTeamNumber";
      var nextStartTeam = isStartingTeam(currentRound + 1, selectedTeam)
          ? "Beginner: Team $selectedTeam"
          : "Beginner: Team $nextOpponentTeamNumber";
      setState(() {
        currentMatchUpText =
            'Aktuell: $disciplineName gegen Team $opponentTeamNumber. $startTeam';
        nextMatchUpText =
            'Coming up: $nextDisciplineName gegen Team $nextOpponentTeamNumber. $nextStartTeam';
      });
    }
  }

  Future<void> _loadSelectedTeam() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int storedSelectedTeam = prefs.getInt('selectedTeam') ?? 0;
    String storedTeamName = prefs.getString('teamName') ?? "";
    if (mounted) {
      setState(() {
        selectedTeam = storedSelectedTeam;
        selectedTeamName = storedTeamName;
      });
    }
  }

  int calculateCurrentRoundWithDateTime() {
    DateTime currentTime = DateTime.now();

    Duration timeDifference = currentTime.difference(_eventStartTime) -
        Duration(seconds: pauseTimeInSeconds);
    int currentRound = timeDifference.inMinutes ~/ roundTimeDuration.inMinutes;
    return currentRound + 1;
  }

  Duration calculateRemainingTimeInRound() {
    DateTime currentTime = DateTime.now();

    int elapsedSeconds =
        currentTime.difference(_eventStartTime).inSeconds - pauseTimeInSeconds;
    int elapsedSecondsInCurrentRound =
        elapsedSeconds % roundTimeDuration.inSeconds;
    int remainingSecondsInCurrentRound =
        roundTimeDuration.inSeconds - elapsedSecondsInCurrentRound;

    return Duration(seconds: remainingSecondsInCurrentRound);
  }

  void updateEventStartTimeInDatabase(DateTime dateTime) {
    if (!mounted) return;

    String dateTimeString = dateTimeToString(dateTime);
    final DatabaseReference databaseReference = FirebaseDatabase.instance.ref();

    databaseReference.child("time").update({
      "startTime": dateTimeString,
    });
  }

  void updateIsPausedInDatabase() {
    if (!mounted) return;
    if (isPaused) {
      getPauseStartTime().then((value) {
        int elapsedSeconds = DateTime.now().difference(value).inSeconds;
        getPauseTime().then((value2) {
          final DatabaseReference databaseReference =
              FirebaseDatabase.instance.ref('/time');
          databaseReference.update({
            "pauseTime": elapsedSeconds + value2,
          });
        });
      });
    } else {
      String dateTimeString = dateTimeToString(DateTime.now());
      final DatabaseReference databaseReference =
          FirebaseDatabase.instance.ref('/time');
      databaseReference.update({
        "pauseStartTime": dateTimeString,
      });
    }
    final DatabaseReference databaseReference =
        FirebaseDatabase.instance.ref('/time');
    databaseReference.update({
      "isPaused": !isPaused,
    });
  }

  Color getRoundCircleColor() {
    if (currentRound > 0 && currentRound < pairings.length) {
      if (calculateRemainingTimeInRound().inSeconds < 60) {
        return Colors.orange;
      } else {
        return Colors.green;
      }
    } else {
      return Colors.red;
    }
  }

  @override
  void dispose() {
    _maxTimeController.dispose();
    _roundTimeController.dispose();
    _eventStartTimeController.dispose();
    _timer.cancel();
    super.dispose();
  }

  Widget getDisciplineImage() {
    switch (getDisciplineName(currentRound, selectedTeam)) {
      case "Kicker":
        return Image.asset(
          "assets/kicker.png",
        );
      case "Darts":
        return Image.asset(
          "assets/darts.png",
        );
      case "Billard":
        return Image.asset(
          "assets/billard.png",
        );
      case "Bierpong":
        return Image.asset(
          "assets/beerpong.png",
        );
      case "Kubb":
        return Image.asset(
          "assets/kubb.png",
        );
      case "Jenga":
        return Image.asset(
          "assets/jenga.png",
        );
      default:
        return Image.asset(
          "assets/pokalganz.png",
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    Duration remainingTime = calculateRemainingTimeInRound();
    String formattedRemainingTime = isPaused
        ? "Pause"
        : '${remainingTime.inMinutes}:${(remainingTime.inSeconds % 60).toString().padLeft(2, '0')}';
    String appBarTitle = 'Olympiade';
    appBarTitle += ' - Team $selectedTeam';
    if (selectedTeamName.isNotEmpty) {
      appBarTitle += ' - $selectedTeamName';
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black12,
        title: Text(appBarTitle, style: const TextStyle(fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.circle, color: getRoundCircleColor()),
                          Text(' Runde $currentRound',
                              style: const TextStyle(fontSize: 18)),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.timer),
                          Text(' Zeit: $formattedRemainingTime',
                              style: const TextStyle(fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(currentMatchUpText,
                          style: const TextStyle(fontSize: 18),
                          textAlign: TextAlign.center),
                    ),
                  ),
                  SizedBox(height: 100, child: getDisciplineImage()),
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(nextMatchUpText,
                          style: const TextStyle(fontSize: 15),
                          textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: FilledButton.tonal(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => UploadResults(
                                    currentRound: currentRound,
                                    teamNumber: selectedTeam)));
                      },
                      child: Text('Ergebnisse eintragen'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, top: 20),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height / 12,
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const DartsRechner()));
                        },
                        child: const Text(
                          'Dartsrechner',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height / 12,
                      width: double.infinity,
                      child: FilledButton.tonal(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16.0),
                        ),
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SchachUhr(
                                        maxtime: maxChessTime.inSeconds,
                                      )));
                        },
                        child: const Text(
                          'Schachuhr',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16.0),
                            ),
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => RulesScreen()));
                            },
                            child: const Text(
                              'Regeln',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16.0),
                            ),
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => SchedulePage(
                                            pairings: pairings,
                                            disciplines: disciplines,
                                            currentRowForColor: currentRound,
                                          )));
                            },
                            child: const Text(
                              'Laufplan',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    _maxTimeController.text = maxChessTime.inSeconds.toString();
    _roundTimeController.text = roundTimeDuration.inMinutes.toString();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _maxTimeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: "Schachuhr Zeit in Sekunden"),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    setState(() {
                      maxChessTime = Duration(
                          seconds:
                              int.tryParse(value) ?? maxChessTime.inSeconds);
                    });
                  },
                ),
                TextField(
                  // New TextField for round time
                  controller: _roundTimeController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: "Rundenzeit in Minuten"),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    setState(() {
                      roundTimeDuration = Duration(
                          minutes: int.tryParse(value) ??
                              roundTimeDuration.inMinutes);
                    });
                  },
                ),
                const SizedBox(height: 16.0),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const TeamSelection(),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text('Teamauswahl'),
                ),
                const SizedBox(height: 16.0),
                const Text("Event Start:"),
                Text(DateFormat('dd MMMM HH:mm').format(_eventStartTime),
                    style: const TextStyle(fontSize: 18)),
                if (selectedTeamName == "Felix99" ||
                    selectedTeamName == "Simon00")
                  FilledButton.tonal(
                    onPressed: () => updateIsPausedInDatabase(),
                    child: const Text("Update Pause in Database"),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}



