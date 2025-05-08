import { getRobotPosition, MatchInfo } from "../../thebluealliance/tba.ts";

// interface ScoreBreakdown { // for reference
//   "activationBonusAchieved": boolean;
//   "autoBridgeState": "Level" | "NotLevel";
//   "autoChargeStationRobot1": "None" | "Docked";
//   "autoChargeStationRobot2": "None" | "Docked";
//   "autoChargeStationRobot3": "None" | "Docked";
//   "autoCommunity": CommunityState;
//   "autoGamePieceCount": number;
//   "autoGamePiecePoints": number;
//   "autoMobilityPoints": number;
//   "autoPoints": number;
//   "coopertitionCriteriaMet": boolean;
//   "endGameBridgeState": "Level" | "NotLevel";
//   "endGameChargeStationRobot1": "None" | "Docked" | "Park";
//   "endGameChargeStationRobot2": "None" | "Docked" | "Park";
//   "endGameChargeStationRobot3": "None" | "Docked" | "Park";
//   "extraGamePieceCount": number;
//   "foulCount": number;
//   "foulPoints": number;
//   "linkPoints": number;
//   "links": {
//     "nodes": number[];
//     "row": "Top" | "Mid" | "Bottom";
//   }[];
//   "mobilityRobot1": "Yes" | "No";
//   "mobilityRobot2": "Yes" | "No";
//   "mobilityRobot3": "Yes" | "No";
//   "rp": number;
//   "sustainabilityBonusAchieved": boolean;
//   "techFoulCount": number;
//   "teleopCommunity": CommunityState;
//   "teleopGamePieceCount": number;
//   "teleopGamePiecePoints": number;
//   "teleopPoints": number;
//   "totalPoints": number;
// }
// interface CommunityState {
//   "B": ("None" | "Cone" | "Cube")[];
//   "M": ("None" | "Cone" | "Cube")[];
//   "T": ("None" | "Cone" | "Cube")[];
// }

export const dbtable = "match_data_2023";
export const dbcolumns = [
  "auto_cone_high",
  "auto_cone_low",
  "auto_cone_mid",
  "auto_cone_misses",
  "auto_cube_high",
  "auto_cube_low",
  "auto_cube_mid",
  "auto_cube_misses",
  "teleop_cone_high",
  "teleop_cone_low",
  "teleop_cone_mid",
  "teleop_cone_misses",
  "teleop_cube_high",
  "teleop_cube_low",
  "teleop_cube_mid",
  "teleop_cube_misses",
  "teleop_intakes_double",
  "teleop_intakes_single",
  "comments_defense",
  "comments_fouls",
]

export function fuseData(
  dbdata: { [key: string]: number },
  team: string,
  tbamatch: MatchInfo,
): { [key: string]: number } {
  const { alliance, index } = getRobotPosition(tbamatch.alliances, team);
  // deno-lint-ignore no-explicit-any
  const scoreBreak: { [key: string]: any } = tbamatch.score_breakdown[alliance];
  dbdata["auto_mobility"] = scoreBreak[`mobilityRobot${index}`] === "Yes" ? 1 : 0;
  const autodocked = scoreBreak[`autoChargeStationRobot${index}`] === "Docked";
  dbdata["auto_docked"] = autodocked ? 1 : 0;
  dbdata["auto_engaged"] = autodocked && scoreBreak.autoBridgeState === "Level" ? 1 : 0;
  dbdata["endgame_parked"] =
    scoreBreak[`endGameChargeStationRobot${index}`] === "Park" ? 1 : 0;
  const endgamedocked =
    scoreBreak[`endGameChargeStationRobot${index}`] === "Docked";
  dbdata["endgame_docked"] = endgamedocked ? 1 : 0;
  dbdata["endgame_engaged"] =
    endgamedocked && scoreBreak.endGameBridgeState === "Level" ? 1 : 0;

  return dbdata;
}

export const scoringpoints = {
  "auto_cone_low": 3,
  "auto_cone_mid": 4,
  "auto_cone_high": 6,
  "auto_cube_low": 3,
  "auto_cube_mid": 4,
  "auto_cube_high": 6,
  "auto_mobility": 3,
  "auto_docked": 8,
  "auto_engaged": 4,
  "teleop_cone_low": 2,
  "teleop_cone_mid": 3,
  "teleop_cone_high": 5,
  "teleop_cube_low": 2,
  "teleop_cube_mid": 3,
  "teleop_cube_high": 5,
  "endgame_parked": 2,
  "endgame_docked": 6,
  "endgame_engaged": 4,
  "comments_fouls": -5
}

export const scoringelements = ["low", "mid", "high", "endgame"];
export const rankingpoints: {[key: string]: (robotinmatch: typeof scoringpoints) => number} = {
  sustainability(_) {
    return 0; // man im not doing all that work for a season we played 2 years ago 
  },
  activation(rim) {
    let sum = 0;
    const objectives = ["auto_docked", "auto_engaged", "endgame_docked", "endgame_engaged"] as (keyof typeof scoringpoints)[];
    for (const objective of objectives) {
      sum += rim[objective] * scoringpoints[objective];
    }
    return sum / 26
  }
}