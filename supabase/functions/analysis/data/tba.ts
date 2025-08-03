import { createSupaClient } from "../supabase/supabase.ts";
import { MatchIdentifier } from "./epa.ts";

// const storageAdapter = new QuickLRU({ maxSize: 4000 });

// Defines parameters for cache lookups/requests
type RequestIdentifier = {
  season: number;
  event?: string;
  team?: string;
};

const cache = new Map();

const client = got.extend({
  cache: new Map(),
  headers: {
    "X-TBA-Auth-Key": Deno.env.get("TBA_KEY")!,
  },
  handlers: [
    (options, next) => {
      if (options.isStream) return next(options);
      const url = typeof options.url === "string"
        ? options.url!
        : options.url!.href;

      const pending = cache.get(url);
      if (pending) return pending;

      const promise = next(options);
      cache.set(url, promise);

      // deno-lint-ignore ban-types
      (promise.on as Function)("end", () => cache.delete(url));
      return promise;
    },
  ],
});

const digitRegex = new RegExp("^\\d+$");
class TBAInterface {
  public getMatches(identifier: RequestIdentifier): Promise<MatchInfo[]> {
    parseInt(identifier.team!, 10)
    if (identifier.team != null && !digitRegex.test(identifier.team)) {
      createSupaClient("").from("match_scouting").select("")
    }
    const resp = client.get(this.buildUrl(identifier));
    return resp.then((r) => {
      console.log(`Request ${r.requestUrl.href} \t Cached: ${r.isFromCache} \t Retry #${r.retryCount}`);
      return JSON.parse(r.body);
    });
  }

  public async getMatch(identifier: MatchIdentifier): Promise<MatchInfo> {
    const matchKey =
      `${identifier.season}${identifier.event}_${identifier.match}`;
    const params = { season: identifier.season, event: identifier.event };

    const data = await this.getMatches(params);
    return data.find((match) => match.key === matchKey)!;
  }

  // Constructs API URL based on parameters
  private buildUrl(identifier: RequestIdentifier): string {
    return "https://www.thebluealliance.com/api/v3" + (
      identifier.team
        ? `/team/frc${identifier.team}` +
          (identifier.event
            ? `/event/${identifier.season}${identifier.event}/matches`
            : `/matches/${identifier.season}`)
        : `/event/${identifier.season}${identifier.event}/matches`
    );
  }
}

export const tba = new TBAInterface();

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
