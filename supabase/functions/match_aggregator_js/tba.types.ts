export interface MatchInfo {
    "comp_level": "qm" | "ef" | "qf" | "sf" | "f",
    "event_key": string, //"2023cacc",
    "key": string, //"2023cacc_qm1",
    "match_number": number,
    "set_number": number,
    "time": number,
    "actual_time": number | null,
    "post_result_time": number | null,
    "predicted_time": number, //1698510065,
    "videos": {type: "youtube" | "tba", key: string}[],
    "alliances": {
      red: AllianceInfo,
      blue: AllianceInfo
    },
    "score_breakdown": {
        red: ScoreBreakdown2023,
        blue: ScoreBreakdown2023
    },
    "winning_alliance": "red" | "blue" | ""
  }
export interface AllianceInfo {
    "dq_team_keys": string[],
    "score": number,
    "surrogate_team_keys": string[],
    "team_keys": string[]
  }
interface ScoreBreakdown2023 {
    "activationBonusAchieved": boolean,
    "autoBridgeState": "Level" | "NotLevel",
    "autoChargeStationRobot1": "None" | "Docked",
    "autoChargeStationRobot2": "None" | "Docked",
    "autoChargeStationRobot3": "None" | "Docked",
    "autoCommunity": CommunityState,
    "autoGamePieceCount": number,
    "autoGamePiecePoints": number,
    "autoMobilityPoints": number,
    "autoPoints": number,
    "coopertitionCriteriaMet": boolean,
    "endGameBridgeState": "Level" | "NotLevel",
    "endGameChargeStationRobot1": "None" | "Docked" | "Park",
    "endGameChargeStationRobot2": "None" | "Docked" | "Park",
    "endGameChargeStationRobot3": "None" | "Docked" | "Park",
    "extraGamePieceCount": number,
    "foulCount": number,
    "foulPoints": number,
    "linkPoints": number,
    "links": {
        "nodes": number[],
        "row": "Top" | "Mid" | "Bottom"
      }[],
    "mobilityRobot1": "Yes" | "No",
    "mobilityRobot2": "Yes" | "No",
    "mobilityRobot3": "Yes" | "No",
    "rp": number,
    "sustainabilityBonusAchieved": boolean,
    "techFoulCount": number,
    "teleopCommunity": CommunityState,
    "teleopGamePieceCount": number,
    "teleopGamePiecePoints": number,
    "teleopPoints": number,
    "totalPoints": number
  }
interface CommunityState {
    "B": ("None" | "Cone" | "Cube")[],
    "M": ("None" | "Cone" | "Cube")[],
    "T": ("None" | "Cone" | "Cube")[]
  }