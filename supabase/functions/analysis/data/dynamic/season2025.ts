import { getRobotPosition, MatchInfo } from "../../thebluealliance/tba.ts";

// interface ScoreBreakdown {
//   "adjustPoints": number,
//   "algaePoints": number,
//   "autoBonusAchieved": boolean,
//   "autoCoralCount": number,
//   "autoCoralPoints": number,
//   "autoLineRobot1": "Yes" | "No",
//   "autoLineRobot2": "Yes" | "No",
//   "autoLineRobot3": "Yes" | "No",
//   "autoMobilityPoints": number,
//   "autoPoints" : number,
//   "autoReef" : Reef,
//   "bargeBonusAchieved" : boolean,
//   "coopertitionCriteriaMet" : boolean,
//   "coralBonusAchieved" : boolean,
//   "endGameBargePoints" : number,
//   "endGameRobot1" : "None" | "Parked" | "ShallowCage" | "DeepCage",
//   "endGameRobot2" : "None" | "Parked" | "ShallowCage" | "DeepCage",
//   "endGameRobot3" : "None" | "Parked" | "ShallowCage" | "DeepCage",
//   "foulCount" : number,
//   "foulPoints" : number,
//   "g206Penalty" : boolean,
//   "g410Penalty" : boolean,
//   "g418Penalty" : boolean,
//   "g428Penalty" : boolean,
//   "netAlgaeCount" : number,
//   "rp" : number,
//   "techFoulCount" : number,
//   "teleopCoralCount" : number,
//   "teleopCoralPoints" : number,
//   "teleopPoints" : number,
//   "teleopReef" : Reef,
//   "totalPoints" : number,
//   "wallAlgaeCount" : number
// }

// interface Reef {
//   "topRow": {
//     "nodeA": boolean;
//     "nodeB": boolean;
//     "nodeC": boolean;
//     "nodeD": boolean;
//     "nodeE": boolean;
//     "nodeF": boolean;
//     "nodeG": boolean;
//     "nodeH": boolean;
//     "nodeI": boolean;
//     "nodeJ": boolean;
//     "nodeK": boolean;
//     "nodeL": boolean;
//   };
//   "midRow": {
//     "nodeA": boolean;
//     "nodeB": boolean;
//     "nodeC": boolean;
//     "nodeD": boolean;
//     "nodeE": boolean;
//     "nodeF": boolean;
//     "nodeG": boolean;
//     "nodeH": boolean;
//     "nodeI": boolean;
//     "nodeJ": boolean;
//     "nodeK": boolean;
//     "nodeL": boolean;
//   };
//   "botRow": {
//     "nodeA": boolean;
//     "nodeB": boolean;
//     "nodeC": boolean;
//     "nodeD": boolean;
//     "nodeE": boolean;
//     "nodeF": boolean;
//     "nodeG": boolean;
//     "nodeH": boolean;
//     "nodeI": boolean;
//     "nodeJ": boolean;
//     "nodeK": boolean;
//     "nodeL": boolean;
//   };
//   "trough" : number;
//   "tba_botRowCount" : number;
//   "tba_midRowCount" : number;
//   "tba_topRowCount" : number;
// }

export const dbtable = "match_data_2025";
export const dbcolumns = [
  "auto_algae_intake_failed",
  "auto_algae_net",
  "auto_algae_net_missed",
  "auto_algae_processor",
  "auto_coral_intake_failed",
  "auto_coral_l1",
  "auto_coral_l2",
  "auto_coral_l3",
  "auto_coral_l4",
  "auto_coral_missed",
  "teleop_algae_intake_failed",
  "teleop_algae_net",
  "teleop_algae_net_missed",
  "teleop_algae_processor",
  "teleop_coral_intake_failed",
  "teleop_coral_l1",
  "teleop_coral_l2",
  "teleop_coral_l3",
  "teleop_coral_l4",
  "teleop_coral_missed",
  "comments_fouls",
  "comments_agility",
  "comments_defense",
]

export function fuseData(
  dbdata: { [key: string]: number },
  teamnum: string,
  tbadata: MatchInfo,
): { [key: string]: number } {
  const { alliance, index } = getRobotPosition(tbadata.alliances, teamnum);
  // deno-lint-ignore no-explicit-any
  const scoreBreak: { [key: string]: any } = tbadata.score_breakdown[alliance];
  
  dbdata["auto_leave"] = scoreBreak[`autoLineRobot${index}`] === "Yes" ? 1 : 0;
  dbdata["endgame_parked"] = dbdata["endgame_shallow"] = dbdata["endgame_deep"] = 0;
  switch (scoreBreak[`endGameRobot${index}`]) {
    case "None":
    break;
    case "Parked": 
      dbdata["endgame_parked"] = 1;
    break;
    case "ShallowCage": 
      dbdata["endgame_shallow"] = 1;
    break;
    case "DeepCage": 
      dbdata["endgame_deep"] = 1;
    break;
  }

  return dbdata;
}

export const scoringpoints = {
  "auto_leave": 3,
  "auto_coral_l1": 3,
  "auto_coral_l2": 4,
  "auto_coral_l3": 6,
  "auto_coral_l4": 7,
  "auto_algae_net": 4,
  "auto_algae_processor": 6,
  "teleop_coral_l1": 2,
  "teleop_coral_l2": 3,
  "teleop_coral_l3": 4,
  "teleop_coral_l4": 5,
  "teleop_algae_net": 4,
  "teleop_algae_processor": 6,
  "endgame_parked": 2,
  "endgame_shallow": 6,
  "endgame_deep": 12,
  "comments_fouls": -3, // average of -2 (normal) and -6 (major)
};

export const scoringelements = ["l1", "l2", "l3", "l4", "processor", "net", "endgame"];

// 1 means this robot single-handedly guarantees that ranking point. See Section 6.5.4 in game manual.
export const rankingpoints: {[key: string]: (robotinmatch: typeof scoringpoints) => number} = {
  auto(robotinmatch) {
    return (robotinmatch.auto_leave / 4) + Math.min(robotinmatch.auto_coral_l1 + robotinmatch.auto_coral_l2 + robotinmatch.auto_coral_l3 + robotinmatch.auto_coral_l4, 1) / 5
  },
  coral(robotinmatch) {
    const coop = Math.min((robotinmatch.auto_algae_processor + robotinmatch.teleop_algae_processor) / 4, 0.5); // This robot's contribution to coop

    const levelcompletion = [
      robotinmatch.auto_coral_l1 + robotinmatch.teleop_coral_l1,
      robotinmatch.auto_coral_l2 + robotinmatch.teleop_coral_l2,
      robotinmatch.auto_coral_l3 + robotinmatch.teleop_coral_l3,
      robotinmatch.auto_coral_l4 + robotinmatch.teleop_coral_l4,
    ].map((level) => Math.min(level / 5, 1)) // The scaled completion of each level
    levelcompletion.sort()
    levelcompletion[3] = 1 - ((1 - levelcompletion[3]) * (1 - coop)) // The least-filled level gets scaled down based on how close to achieving coop we are

    return levelcompletion.reduce((a, b) => a + b, 0) / 4; // Sum together each level's completion and normalize
  },
  endgame(robotinmatch) {
    return Math.min((
      (robotinmatch.endgame_parked ?? 0) * scoringpoints.endgame_parked +
      (robotinmatch.endgame_shallow ?? 0) * scoringpoints.endgame_shallow +
      (robotinmatch.endgame_deep ?? 0) * scoringpoints.endgame_deep
    ) / 14, 1);
  }
}