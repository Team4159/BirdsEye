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
