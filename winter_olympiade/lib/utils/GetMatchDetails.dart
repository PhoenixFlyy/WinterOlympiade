import 'package:firebase_database/firebase_database.dart';

import 'DateTimeUtils.dart';
import 'MatchDetails.dart';

bool isStartingTeam(int round, int teamNumber) {
  if (round > 0 && round <= pairings.length) {
    var pairing = pairings[round - 1];
    for (String match in pairing) {
      if (match.contains(teamNumber.toString())) {
        var teams = match.split('-');
        return teams[0].contains(teamNumber.toString());
      }
    }
  }
  return false;
}

String getDisciplineName(int round, int teamNumber) {
  if (round > 0 && round <= pairings.length) {
    var pairing = pairings[round - 1];
    for (int index = 0; index < pairing.length; index++) {
      var match = pairing[index];
      if (match.contains(teamNumber.toString())) {
        return disciplines[(index + 1).toString()] ?? "Unknown Discipline";
      }
    }
  }
  return "Failed";
}

int getDisciplineNumber(int round, int teamNumber) {
  if (round > 0 && round <= pairings.length) {
    var pairing = pairings[round - 1];
    for (int index = 0; index < pairing.length; index++) {
      var match = pairing[index];
      if (match.contains(teamNumber.toString())) {
        return index + 1;
      }
    }
  }
  return 0;
}

int getOpponentTeamNumber(int round, int teamNumber) {
  if (round > 0 && round <= pairings.length) {
    var pairing = pairings[round - 1];
    for (int index = 0; index < pairing.length; index++) {
      var match = pairing[index];
      if (match.contains(teamNumber.toString())) {
        var teams = match.split('-');
        if (teams[0].contains(teamNumber.toString())) {
          return int.tryParse(teams[1]) ?? -1;
        } else {
          return int.tryParse(teams[0]) ?? -1;
        }
      }
    }
  }
  return -2;
}

Future<double> getTeamPointsInRound(int round, int teamNumber) async {
  if (round > 0 && round <= pairings.length && teamNumber > 0) {
    var teamOrderString = isStartingTeam(round, teamNumber) ? "team1" : "team2";
    var databaseRound = (round - 1).toString();
    var disciplineNumber =
        (getDisciplineNumber(round, teamNumber) - 1).toString();

    DatabaseReference databaseParent = FirebaseDatabase.instance.ref(
        '/results/rounds/$databaseRound/matches/$disciplineNumber/$teamOrderString');
    DatabaseEvent event = await databaseParent.once();
    return double.tryParse(event.snapshot.value.toString()) ?? -1.0;
  }
  return -2;
}

Future<List<double>> getAllTeamPointsInDiscipline(
    int disciplineNumber, int teamNumber) async {
  List<double> summarizedPointList = [];
  for (int index = 0; index < pairings.length; index++) {
    var pairing = pairings[index];
    var match = pairing[disciplineNumber - 1];
    if (match.contains(teamNumber.toString())) {
      var teams = match.split('-');
      var teamOrderString =
          teams[0].contains(teamNumber.toString()) ? "team1" : "team2";

      DatabaseReference databaseMatch = FirebaseDatabase.instance.ref(
          '/results/rounds/$index/matches/${disciplineNumber - 1}/$teamOrderString');
      DatabaseEvent event = await databaseMatch.once();
      summarizedPointList
          .add(double.tryParse(event.snapshot.value.toString()) ?? 0.0);
    }
  }
  return summarizedPointList;
}

Future<DateTime> getOlympiadeStartDateTime() async {
  DatabaseReference databaseParent =
      FirebaseDatabase.instance.ref('/time/startTime');
  DatabaseEvent event = await databaseParent.once();
  return stringToDateTime(event.snapshot.value.toString());
}

Future<DateTime> getPauseStartTime() async {
  DatabaseReference databaseParent =
      FirebaseDatabase.instance.ref('/time/pauseStartTime');
  DatabaseEvent event = await databaseParent.once();
  return stringToDateTime(event.snapshot.value.toString());
}

Future<int> getPauseTime() async {
  DatabaseReference databaseParent =
      FirebaseDatabase.instance.ref('/time/pauseTime');
  DatabaseEvent event = await databaseParent.once();
  return int.tryParse(event.snapshot.value.toString()) ?? 0;
}