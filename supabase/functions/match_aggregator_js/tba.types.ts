export interface MatchInfo {
  "comp_level": "qm" | "ef" | "qf" | "sf" | "f";
  "event_key": string; //"2023cacc",
  "key": string; //"2023cacc_qm1",
  "match_number": number;
  "set_number": number;
  "time": number;
  "actual_time": number | null;
  "post_result_time": number | null;
  "predicted_time": number; //1698510065,
  "videos": { type: "youtube" | "tba"; key: string }[];
  "alliances": {
    red: AllianceInfo;
    blue: AllianceInfo;
  };
  "score_breakdown": {
    red: object;
    blue: object;
  };
  "winning_alliance": "red" | "blue" | "";
}

export interface AllianceInfo {
  "dq_team_keys": string[];
  "score": number;
  "surrogate_team_keys": string[];
  "team_keys": string[];
}

export function getRobotPosition(
  alliances: { red: AllianceInfo; blue: AllianceInfo },
  team: string,
): { alliance: "red" | "blue"; index: number } {
  for (const [alliance, info] of Object.entries(alliances)) {
    const i = info.team_keys.indexOf(`frc${team}`);
    if (i !== -1) {
      return { "alliance": alliance as "red" | "blue", index: i + 1 };
    }
  }
  throw new Error("Invalid Robot Position");
}