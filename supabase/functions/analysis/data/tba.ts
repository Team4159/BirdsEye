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

// Defines parameters for cache lookups/requests
type CacheParams = {
  season: number;
  event?: string;
  team?: string;
};

// Serialization/deserialization for cache keys
function serialize(obj: CacheParams): string {
  return [obj.season, obj.event ?? "", obj.team ?? ""].join("|");
}
// function _deserialize(str: string): CacheParams {
//   const [season, event, team] = str.split("|");
//   return { season: parseNatural(season)!, event, team };
// }

class TBAInterface {
  private readonly cache: Map<string, MatchInfo[]> = new Map();
  private readonly pendingRequests: Map<string, Promise<MatchInfo[]>> = new Map();
  private readonly APIKEY: string = Deno.env.get("TBA_KEY")!;

  // Retrieves cached data for exact parameters
  private cacheGet(params: CacheParams): MatchInfo[] | undefined {
    return this.cache.get(serialize(params));
  }

  // Updates cache with new data, handles deletion for undefined
  private cacheSet(params: CacheParams, data: MatchInfo[] | undefined) {
    if (!data) this.cache.delete(serialize(params));
    else this.cache.set(serialize(params), data);
  }

  // Fetches fresh data and updates cache
  async fresh(params: CacheParams): Promise<MatchInfo[]> {
    const data = await this.fetchWithRetry(this.buildUrl(params));
    this.cacheSet(params, data);
    return data;
  }

  // Retrieves data with cache-first strategy
  async get(params: CacheParams): Promise<MatchInfo[]> {
    const cached = this.cacheGet(params);
    if (cached !== undefined) return cached;

    // 2. Check broader cached data and filter
    const broader = this.cacheGetBroader(params);
    if (broader) {
      this.cacheSet(params, broader); // Cache filtered results
      return broader;
    }

    // 3. Fallback to API request
    return await this.fresh(params);
  }

  async getMatch(identifier: MatchIdentifier): Promise<MatchInfo> {
    const matchKey = `${identifier.season}${identifier.event}_${identifier.match}`
    const params = { season: identifier.season, event: identifier.event }

    const data = await this.get(params);
    return data.find((match) => match.key === matchKey)!
  }

  // Constructs API URL based on parameters
  private buildUrl(params: CacheParams): string {
    return "https://www.thebluealliance.com/api/v3" + (
      params.team
        ? `/team/frc${params.team}` +
          (params.event
            ? `/event/${params.season}${params.event}/matches`
            : `/matches/${params.season}`)
        : `/event/${params.season}${params.event}/matches`
    );
  }

  // Handles smart fetching, combining identical requests into one and retrying with exponential backoff.
  private async fetchWithRetry(url: string, retries = 3): Promise<MatchInfo[]> { // TODO: doesn't cache aggressively enough. Frequently double-requests.
    if (url in this.pendingRequests) return this.pendingRequests.get(url)!;

    const fetchPromise = (async () => {
      let delay = 1000;
      for (let i = 0; i < retries; i++) {
        try {
          console.log(`fetch("${url}", #${i})`)
          const response = await fetch(url, {
            headers: { "X-TBA-Auth-Key": this.APIKEY },
          });
  
          if (!response.ok) {
            console.warn(await response.text())
            throw new Error(`HTTP ${response.status}`);
          }
          return await response.json();
        } catch (error) {
          if (i === retries - 1) throw error;
          await new Promise((resolve) => setTimeout(resolve, delay));
          delay *= 2;
        }
      }
    })();

    this.pendingRequests.set(url, fetchPromise)
    try {
      return await fetchPromise;
    } finally {
      this.pendingRequests.delete(url);
    }
  }

  // Checks for broader cached datasets that can be filtered
  private cacheGetBroader(params: CacheParams): MatchInfo[] | undefined {
    if (!params.event || !params.team) return; // Already broadest possible query

    const season = params.season;
    const eventKey = `${params.season}${params.event!}`;
    const teamKey = `frc${params.team!}`;
    return this.cacheGet({ season, event: params.event })?.filter((m) =>
        m.alliances.red.team_keys.includes(teamKey) ||
        m.alliances.blue.team_keys.includes(teamKey)
      ) ||
      this.cacheGet({ season, team: params.team })?.filter((m) =>
        m.event_key === eventKey
      );
  }
}

export const tba = new TBAInterface();
