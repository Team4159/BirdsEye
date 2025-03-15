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
    teamdata: { [key: string]: Set<number> },
    team: string,
    tbamatch: MatchInfo,
  ) {
    const { alliance, index } = getRobotPosition(tbamatch.alliances, team);

    const scoreBreak: { [key: string]: any } = tbamatch.score_breakdown[alliance];

    teamdata["auto_leave"] = new Set([scoreBreak[`autoLineRobot${index}`] === "Yes" ? 1 : 0]);
    let f: number[];

    const parkstatus = scoreBreak[`endGameRobot${index}`];
    if (parkstatus === "None") return;
    if (parkstatus === "Parked") {teamdata["endgame_parked"] = new Set([1]); return;}
    if (parkstatus === "ShallowCage") {teamdata["endgame_shallow_cage"] = new Set([1]); return;}
    if (parkstatus === "DeepCage") {teamdata["endgame_deep_cage"] = new Set([1]); return;}
  }
