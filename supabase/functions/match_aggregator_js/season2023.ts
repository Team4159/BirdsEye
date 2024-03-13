import { MatchInfo, getRobotPosition } from "./tba.types.ts";

interface ScoreBreakdown { // for reference
  "activationBonusAchieved": boolean;
  "autoBridgeState": "Level" | "NotLevel";
  "autoChargeStationRobot1": "None" | "Docked";
  "autoChargeStationRobot2": "None" | "Docked";
  "autoChargeStationRobot3": "None" | "Docked";
  "autoCommunity": CommunityState;
  "autoGamePieceCount": number;
  "autoGamePiecePoints": number;
  "autoMobilityPoints": number;
  "autoPoints": number;
  "coopertitionCriteriaMet": boolean;
  "endGameBridgeState": "Level" | "NotLevel";
  "endGameChargeStationRobot1": "None" | "Docked" | "Park";
  "endGameChargeStationRobot2": "None" | "Docked" | "Park";
  "endGameChargeStationRobot3": "None" | "Docked" | "Park";
  "extraGamePieceCount": number;
  "foulCount": number;
  "foulPoints": number;
  "linkPoints": number;
  "links": {
    "nodes": number[];
    "row": "Top" | "Mid" | "Bottom";
  }[];
  "mobilityRobot1": "Yes" | "No";
  "mobilityRobot2": "Yes" | "No";
  "mobilityRobot3": "Yes" | "No";
  "rp": number;
  "sustainabilityBonusAchieved": boolean;
  "techFoulCount": number;
  "teleopCommunity": CommunityState;
  "teleopGamePieceCount": number;
  "teleopGamePiecePoints": number;
  "teleopPoints": number;
  "totalPoints": number;
}
interface CommunityState {
  "B": ("None" | "Cone" | "Cube")[];
  "M": ("None" | "Cone" | "Cube")[];
  "T": ("None" | "Cone" | "Cube")[];
}

export default function (
  teamdata: { [key: string]: Set<number> },
  team: string,
  tbamatch: MatchInfo,
) {
  const { alliance, index } = getRobotPosition(tbamatch.alliances, team);
  // deno-lint-ignore no-explicit-any
  const scoreBreak: { [key: string]: any } = tbamatch.score_breakdown[alliance];
  teamdata["auto_mobility"] = new Set([
    scoreBreak[`mobilityRobot${index}`] === "Yes" ? 1 : 0,
  ]);
  const autodocked = scoreBreak[`autoChargeStationRobot${index}`] === "Docked";
  teamdata["auto_docked"] = new Set([autodocked ? 1 : 0]);
  teamdata["auto_engaged"] = new Set([
    autodocked && scoreBreak.autoBridgeState === "Level" ? 1 : 0,
  ]);
  teamdata["endgame_parked"] = new Set([
    scoreBreak[`endGameChargeStationRobot${index}`] === "Park" ? 1 : 0,
  ]);
  const endgamedocked =
    scoreBreak[`endGameChargeStationRobot${index}`] === "Docked";
  teamdata["endgame_docked"] = new Set([endgamedocked ? 1 : 0]);
  teamdata["endgame_engaged"] = new Set([
    endgamedocked && scoreBreak.endGameBridgeState === "Level" ? 1 : 0,
  ]);
}
