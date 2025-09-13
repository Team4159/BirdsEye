import { createFetcher } from "../fetcher.ts";
import { MatchIdentifier } from "./epa.ts";

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

interface AllianceInfo {
  "dq_team_keys": string[];
  "score": number;
  "surrogate_team_keys": string[];
  "team_keys": string[];
}

export function getRobotPosition(
  alliances: { red: AllianceInfo; blue: AllianceInfo },
  robot: string,
): { alliance: keyof typeof alliances; index: number } {
  for (const [alliance, info] of Object.entries(alliances)) {
    const i = info.team_keys.indexOf(`frc${robot}`);
    if (i === -1) continue;
    return { "alliance": alliance as keyof typeof alliances, index: i + 1 };
  }
  throw new Error("Invalid Robot Position");
}

type FetchParams = {
  season: number;
  event?: string;
  robot?: string;
};

class TBAInterface {
  private readonly axios = createFetcher();

  getMatches(identifier: FetchParams) {
    return this.axios.get(TBAInterface.buildUrl(identifier), {
      headers: { "X-TBA-Auth-Key": Deno.env.get("TBA_KEY")! },
    }).then((r) => r.data as MatchInfo[]);
  }

  async getMatch(identifier: MatchIdentifier): Promise<MatchInfo> {
    const matchKey =
      `${identifier.season}${identifier.event}_${identifier.match}`;
    const params = { season: identifier.season, event: identifier.event };

    const data = await this.getMatches(params);
    return data.find((match) => match.key === matchKey)!;
  }
  // Constructs API URL based on parameters
  private static buildUrl(params: FetchParams): string {
    return "https://www.thebluealliance.com/api/v3" + (
      params.robot
        ? `/team/frc${params.robot}` +
          (params.event
            ? `/event/${params.season}${params.event}/matches`
            : `/matches/${params.season}`)
        : `/event/${params.season}${params.event}/matches`
    );
  }
}

export const tba = new TBAInterface();
