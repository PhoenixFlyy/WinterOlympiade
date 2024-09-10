import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:olympiade/utils/main_menu_navigation_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../setup/result_screen.dart';
import '../utils/date_time_picker.dart';
import '../utils/date_time_utils.dart';
import '../utils/match_data.dart';
import '../utils/match_detail_queries.dart';
import '../utils/play_sounds.dart';
import 'main_menu_body.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  late Timer _timer;
  String currentMatchUpText = '';
  String nextMatchUpText = '';

  final audioService = AudioService();

  Duration maxChessTime = const Duration(minutes: 4);
  Duration roundTimeDuration = const Duration(minutes: 12);
  Duration playTimeDuration = const Duration(minutes: 10);

  final _roundTimeController = TextEditingController();
  final _playTimeController = TextEditingController();
  final _maxChessTimeController = TextEditingController();

  int currentRound = 0;
  bool isPaused = false;
  int pauseTimeInSeconds = 0;
  DateTime pauseStartTime = DateTime.now();

  int selectedTeam = 0;
  String selectedTeamName = "";

  DateTime _eventStartTime = DateTime.now();
  DateTime _eventEndTime = DateTime.now();

  final DatabaseReference _databaseTime = FirebaseDatabase.instance.ref('/time');

  bool isFirstRenderingWhistle = true;

  void _activateDatabaseTimeListener() {
    _databaseTime.child("isPaused").onValue.listen((event) {
      final bool streamIsPaused = event.snapshot.value.toString().toLowerCase() == 'true';
      if (!isFirstRenderingWhistle && streamIsPaused) {
        audioService.playWhistleSound();
      }
      if (!isFirstRenderingWhistle && !streamIsPaused) {
        audioService.playStartSound();
      }
      setState(() {
        isPaused = streamIsPaused;
      });
      if (isFirstRenderingWhistle) {
        isFirstRenderingWhistle = false;
      }
    });
    _databaseTime.child("pauseTime").onValue.listen((event) {
      final int streamPauseTime = int.tryParse(event.snapshot.value.toString()) ?? 0;
      setState(() {
        pauseTimeInSeconds = streamPauseTime;
      });
    });
    _databaseTime.child("startTime").onValue.listen((event) {
      final DateTime streamEventStartTime = stringToDateTime(event.snapshot.value.toString());
      setState(() {
        _eventStartTime = streamEventStartTime;
        currentRound = calculateCurrentRoundWithDateTime();
      });
    });
    _databaseTime.child("pauseStartTime").onValue.listen((event) {
      final DateTime streamPauseStartTime = stringToDateTime(event.snapshot.value.toString());
      setState(() {
        pauseStartTime = streamPauseStartTime;
      });
    });
    _databaseTime.child("chessTime").onValue.listen((event) {
      final Duration streamChessTime = Duration(seconds: int.tryParse(event.snapshot.value.toString()) ?? 240);
      setState(() {
        maxChessTime = streamChessTime;
      });
    });

    _databaseTime.child("roundTime").onValue.listen((event) {
      final Duration streamRoundTime = Duration(minutes: int.tryParse(event.snapshot.value.toString()) ?? 12);
      setState(() {
        roundTimeDuration = streamRoundTime;
      });
    });
    _databaseTime.child("playTime").onValue.listen((event) {
      final Duration streamPlayTime = Duration(minutes: int.tryParse(event.snapshot.value.toString()) ?? 10);
      setState(() {
        playTimeDuration = streamPlayTime;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSelectedTeam();
    _setUpTimer();
    _activateDatabaseTimeListener();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _maxChessTimeController.dispose();
    _roundTimeController.dispose();
    _playTimeController.dispose();
    _timer.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _setUpTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), _updateTimerCallback);
    _updateCurrentRound();
    _updateMatchAndDiscipline();
  }

  void _updateTimerCallback(Timer timer) {
    if (!isPaused) {
      _updateCurrentRound();
      _updateMatchAndDiscipline();
    }
    calculateEventEndTime();
  }

  void calculateEventEndTime() {
    Duration calculatedDuration =
        Duration(minutes: pairings.length * roundTimeDuration.inMinutes) + Duration(seconds: pauseTimeInSeconds);
    if (isPaused) {
      calculatedDuration += DateTime.now().difference(pauseStartTime);
    }
    setState(() {
      _eventEndTime = _eventStartTime.add(calculatedDuration);
    });
  }

  void _updateCurrentRound() {
    int newCurrentRound = calculateCurrentRoundWithDateTime();
    if (newCurrentRound != currentRound) audioService.playStartSound();

    setState(() {
      currentRound = newCurrentRound;
    });
  }

  void _updateMatchAndDiscipline() {
    if (currentRound > 0 && currentRound <= pairings.length) {
      var opponentTeamNumber = getOpponentTeamNumberByRound(currentRound, selectedTeam);
      var nextOpponentTeamNumber = getOpponentTeamNumberByRound(currentRound + 1, selectedTeam);
      var disciplineName = getDisciplineName(currentRound, selectedTeam);
      var nextDisciplineName = getDisciplineName(currentRound + 1, selectedTeam);
      var startTeam =
          isStartingTeam(currentRound, selectedTeam) ? "Beginner: Team $selectedTeam" : "Beginner: Team $opponentTeamNumber";
      var nextStartTeam = isStartingTeam(currentRound + 1, selectedTeam)
          ? "Beginner: Team $selectedTeam"
          : "Beginner: Team $nextOpponentTeamNumber";
      setState(() {
        if (calculateRemainingTimeInRound().inSeconds <= (roundTimeDuration.inSeconds - playTimeDuration.inSeconds)) {
          currentMatchUpText = 'Wechseln. Bitte alles so aufbauen wie es vorher war!';
        } else {
          currentMatchUpText = 'Aktuell: $disciplineName gegen Team $opponentTeamNumber. $startTeam';
        }

        nextMatchUpText = 'Coming up: $nextDisciplineName gegen Team $nextOpponentTeamNumber. $nextStartTeam';
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

    Duration timeDifference = currentTime.difference(_eventStartTime) - Duration(seconds: pauseTimeInSeconds);
    int currentRound = timeDifference.inMinutes ~/ roundTimeDuration.inMinutes;
    if (timeDifference.isNegative) return 0;
    return currentRound + 1;
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    String days = duration.inDays != 0 ? '${duration.inDays} d ' : '';
    String hours = '${twoDigits(duration.inHours.remainder(24))} h ';
    String minutes = '${twoDigits(duration.inMinutes.remainder(60))} Min';

    return days + hours + minutes;
  }

  Duration calculateRemainingTimeInRound() {
    DateTime currentTime = DateTime.now();

    if (currentTime.isBefore(_eventStartTime)) {
      return _eventStartTime.difference(currentTime);
    }
    if (currentTime.isAfter(_eventEndTime)) {
      return currentTime.difference(_eventEndTime);
    }

    int elapsedSeconds = currentTime.difference(_eventStartTime).inSeconds - pauseTimeInSeconds;
    int elapsedSecondsInCurrentRound = elapsedSeconds % roundTimeDuration.inSeconds;
    int remainingSecondsInCurrentRound = roundTimeDuration.inSeconds - elapsedSecondsInCurrentRound;

    if (remainingSecondsInCurrentRound ==
        (roundTimeDuration.inSeconds - playTimeDuration.inSeconds + const Duration(seconds: 60).inSeconds)) {
      audioService.playWhooshSound();
    }
    if (remainingSecondsInCurrentRound == (roundTimeDuration.inSeconds - playTimeDuration.inSeconds)) {
      audioService.playGongAkkuratSound();
    }
    return Duration(seconds: remainingSecondsInCurrentRound);
  }

  void updateIsPausedInDatabase() {
    if (!mounted) return;
    if (isPaused) {
      getPauseStartTime().then((value) {
        int elapsedSeconds = DateTime.now().difference(value).inSeconds;
        getPauseTime().then((value2) {
          final DatabaseReference databaseReference = FirebaseDatabase.instance.ref('/time');
          databaseReference.update({
            "pauseTime": elapsedSeconds + value2,
          });
        });
      });
    } else {
      String dateTimeString = dateTimeToString(DateTime.now());
      final DatabaseReference databaseReference = FirebaseDatabase.instance.ref('/time');
      databaseReference.update({
        "pauseStartTime": dateTimeString,
      });
    }
    final DatabaseReference databaseReference = FirebaseDatabase.instance.ref('/time');
    databaseReference.update({
      "isPaused": !isPaused,
    });
  }

  void updateChessTimeInDatabase() {
    if (!mounted) return;
    final DatabaseReference databaseReference = FirebaseDatabase.instance.ref('/time');
    databaseReference.update({
      "chessTime": maxChessTime.inSeconds,
    });
  }

  void updateRoundTimeInDatabase() {
    if (!mounted) return;
    if (!mounted) return;
    final DatabaseReference databaseReference = FirebaseDatabase.instance.ref('/time');
    databaseReference.update({
      "roundTime": roundTimeDuration.inMinutes,
      "playTime": playTimeDuration.inMinutes,
    });
  }

  Color getRoundCircleColor() {
    if (currentRound > 0 && currentRound <= pairings.length) {
      if (calculateRemainingTimeInRound().inSeconds < (roundTimeDuration.inSeconds - playTimeDuration.inSeconds)) {
        return Colors.red;
      } else if (calculateRemainingTimeInRound().inSeconds <
          (roundTimeDuration.inSeconds - playTimeDuration.inSeconds + const Duration(seconds: 60).inSeconds)) {
        return Colors.orange;
      } else {
        return Colors.green;
      }
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = 'Team $selectedTeam';
    if (selectedTeamName.isNotEmpty) {
      appBarTitle += ' - $selectedTeamName';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(appBarTitle, style: const TextStyle(fontSize: 20)),
        actions: [
          if (selectedTeamName == "Felix99" || selectedTeamName == "Simon00")
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _openSettings(),
            ),
        ],
      ),
      drawer: MainMenuNavigationDrawer(
          currentRound: currentRound,
          selectedRound: currentRound,
          teamNumber: selectedTeam,
          eventStartTime: _eventStartTime,
          eventEndTime: _eventEndTime,
          maxChessTime: maxChessTime.inSeconds),
      body: MainMenuBody(
        currentRound: currentRound,
        selectedTeam: selectedTeam,
        maxChessTime: maxChessTime,
        isPaused: isPaused,
        currentMatchUpText: currentMatchUpText,
        nextMatchUpText: nextMatchUpText,
        remainingTime: calculateRemainingTimeInRound(),
        selectedTeamName: selectedTeamName,
        getRoundCircleColor: getRoundCircleColor,
      ),
    );
  }

  void _openSettings() {
    _maxChessTimeController.text = maxChessTime.inSeconds.toString();
    _roundTimeController.text = roundTimeDuration.inMinutes.toString();
    _playTimeController.text = playTimeDuration.inMinutes.toString();

    showModalBottomSheet(
      backgroundColor: Colors.black,
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(31.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Text("Beginn:", style: TextStyle(fontSize: 18)),
                      Text(DateFormat(' dd.MM.yyyy, HH:mm').format(_eventStartTime), style: const TextStyle(fontSize: 18)),
                      const Text(" Uhr", style: TextStyle(fontSize: 18)),
                      TimePickerWidget(
                          currentEventStartTime: _eventStartTime,
                          onDateTimeSelected: (newTime) {
                            final DatabaseReference databaseReference = FirebaseDatabase.instance.ref('/time');
                            databaseReference.update({
                              "pauseTime": 0,
                              "startTime": dateTimeToString(newTime),
                            });
                          }),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 75,
                        width: 200,
                        child: TextField(
                          controller: _maxChessTimeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Schachuhr Zeit in Sekunden"),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (value) {
                            setState(() {
                              maxChessTime = Duration(seconds: int.tryParse(value) ?? maxChessTime.inSeconds);
                            });
                          },
                        ),
                      ),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => updateChessTimeInDatabase(),
                        child: const Text("Update"),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 75,
                        width: 200,
                        child: TextField(
                          controller: _roundTimeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Rundenzeit in Minuten"),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (value) {
                            setState(() {
                              roundTimeDuration = Duration(minutes: int.tryParse(value) ?? roundTimeDuration.inMinutes);
                            });
                          },
                        ),
                      ),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => updateRoundTimeInDatabase(),
                        child: const Text("Update"),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 75,
                        width: 200,
                        child: TextField(
                          controller: _playTimeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Spielzeit einer Runde"),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (value) {
                            setState(() {
                              playTimeDuration = Duration(minutes: int.tryParse(value) ?? playTimeDuration.inMinutes);
                            });
                          },
                        ),
                      ),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => updateRoundTimeInDatabase(),
                        child: const Text("Update"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => updateIsPausedInDatabase(),
                    child: const Text("Update Pause in Database"),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ResultScreen(),
                        ),
                      );
                    },
                    child: const Text('Ergebnisse anschauen'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}