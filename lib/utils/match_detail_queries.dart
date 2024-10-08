import 'package:firebase_database/firebase_database.dart';

import 'date_time_utils.dart';
import 'match_data.dart';

bool isNumberInString(String input, int number) {
  List<String> parts = input.split("-");
  for (String part in parts) {
    if (int.tryParse(part) == number) {
      return true;
    }
  }
  return false;
}

bool isStartingTeam(int round, int teamNumber) {
  if (round > 0 && round <= pairings.length) {
    var pairing = pairings[round - 1];
    for (String match in pairing) {
      if (isNumberInString(match, teamNumber)) {
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
      if (isNumberInString(match, teamNumber)) {
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
      if (isNumberInString(match, teamNumber)) {
        return index + 1;
      }
    }
  }
  return 0;
}

int getOpponentTeamNumberByRound(int round, int teamNumber) {
  if (round > 0 && round <= pairings.length) {
    var pairing = pairings[round - 1];
    for (int index = 0; index < pairing.length; index++) {
      var match = pairing[index];
      if (isNumberInString(match, teamNumber)) {
        var teams = match.split('-');
        if (int.tryParse(teams[0]) == teamNumber) {
          return int.tryParse(teams[1]) ?? -1;
        } else {
          return int.tryParse(teams[0]) ?? -1;
        }
      }
    }
  }
  return -2;
}

List<int> getOpponentListByDisciplines(int disciplineNumber, int teamNumber) {
  List<int> opponentsInDiscipline = [];
  for (int index = 0; index < pairings.length; index++) {
    var match = pairings[index][disciplineNumber - 1];
    if (isNumberInString(match, teamNumber)) {
      var teams = match.split('-');
      if (int.tryParse(teams[0]) == teamNumber) {
        opponentsInDiscipline.add(int.tryParse(teams[1]) ?? -1);
      } else {
        opponentsInDiscipline.add(int.tryParse(teams[0]) ?? -1);
      }
    }
  }
  return opponentsInDiscipline;
}

Future<List<double>> getAllTeamPointsInDisciplineSortedByMatch(
    int disciplineNumber, int teamNumber) async {
  List<double> summarizedPointList = [];
  for (int index = 0; index < pairings.length; index++) {
    var pairing = pairings[index];
    var match = pairing[disciplineNumber - 1];
    if (isNumberInString(match, teamNumber)) {
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