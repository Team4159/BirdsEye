import { MatchInfo, getRobotPosition } from "./tba.types.ts";

interface ScoreBreakdown {
  "adjustPoints": number,
  "algaePoints": number,
  "autoBonusAchieved": boolean,
  "autoCoralCount": number,
  "autoCoralPoints": number,
  "autoLineRobot1": "Yes" | "No",
  "autoLineRobot2": "Yes" | "No",
  "autoLineRobot3": "Yes" | "No",
  "autoMobilityPoints": number,
  "autoPoints" : number,
  "autoReef" : Reef,
  "bargeBonusAchieved" : boolean,
  "coopertitionCriteriaMet" : boolean,
  "coralBonusAchieved" : boolean,
  "endGameBargePoints" : number,
  "endGameRobot1" : "None" | "Parked" | "ShallowCage" | "DeepCage",
  "endGameRobot2" : "None" | "Parked" | "ShallowCage" | "DeepCage",
  "endGameRobot3" : "None" | "Parked" | "ShallowCage" | "DeepCage",
  "foulCount" : number,
  "foulPoints" : number,
  "g206Penalty" : boolean,
  "g410Penalty" : boolean,
  "g418Penalty" : boolean,
  "g428Penalty" : boolean,
  "netAlgaeCount" : number,
  "rp" : number,
  "techFoulCount" : number,
  "teleopCoralCount" : number,
  "teleopCoralPoints" : number,
  "teleopPoints" : number,
  "teleopReef" : Reef,
  "totalPoints" : number,
  "wallAlgaeCount" : number
}

interface Reef {
  "topRow": {
    "nodeA": boolean;
    "nodeB": boolean;
    "nodeC": boolean;
    "nodeD": boolean;
    "nodeE": boolean;
    "nodeF": boolean;
    "nodeG": boolean;
    "nodeH": boolean;
    "nodeI": boolean;
    "nodeJ": boolean;
    "nodeK": boolean;
    "nodeL": boolean;
  };
  "midRow": {
    "nodeA": boolean;
    "nodeB": boolean;
    "nodeC": boolean;
    "nodeD": boolean;
    "nodeE": boolean;
    "nodeF": boolean;
    "nodeG": boolean;
    "nodeH": boolean;
    "nodeI": boolean;
    "nodeJ": boolean;
    "nodeK": boolean;
    "nodeL": boolean;
  };
  "botRow": {
    "nodeA": boolean;
    "nodeB": boolean;
    "nodeC": boolean;
    "nodeD": boolean;
    "nodeE": boolean;
    "nodeF": boolean;
    "nodeG": boolean;
    "nodeH": boolean;
    "nodeI": boolean;
    "nodeJ": boolean;
    "nodeK": boolean;
    "nodeL": boolean;
  };
  "trough" : number;
  "tba_botRowCount" : number;
  "tba_midRowCount" : number;
  "tba_topRowCount" : number;
}

export default function (
  dbdata: { [key: string]: Set<number> },
  teamnum: string,
  tbadata: MatchInfo,
) {
  const { alliance, index } = getRobotPosition(tbadata.alliances, teamnum);
  // deno-lint-ignore no-explicit-any
  const scoreBreak: { [key: string]: any } = tbadata.score_breakdown[alliance];
  
  dbdata["auto_leave"] = new Set([scoreBreak[`autoLineRobot${index}`] === "Yes" ? 1 : 0]);
  switch (scoreBreak[`endGameRobot${index}`]) {
    case "None":
    break;
    case "Parked": 
      dbdata["endgame_parked"] = new Set([1]);
    break;
    case "ShallowCage": 
      dbdata["endgame_shallow"] = new Set([1]);
    break;
    case "DeepCage": 
      dbdata["endgame_deep"] = new Set([1]);
    break;
  }
}
