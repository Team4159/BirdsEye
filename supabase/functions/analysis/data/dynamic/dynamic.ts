import { MatchInfo } from "../../thebluealliance/tba.ts";
import * as season2023 from "./season2023.ts";
import * as season2024 from "./season2024.ts";
import * as season2025 from "./season2025.ts";

/**
 * Configuration map for different seasons containing:
 * - dbtable: Database table name for the season
 * - dbcolumns: List of columns to query (must be numeric/boolean)
 * - fuseData: Function to merge DB and TBA data
 * - scoringpoints: Map of point values for each scoring objective
 * - scoringelements: List of strings included in objective names to categorize them
 */
const dynamicMap: {
  [key: number]: {
    dbtable: string;
    dbcolumns: string[];
    fuseData: (
      dbdata: { [key: string]: number },
      team: string,
      tbadata: MatchInfo,
    ) => { [key: string]: number };
    scoringpoints: { [key: string]: number },
    scoringelements: string[],
    // the type for "robotinmatch" is any to permit each item to constrain it to `typeof scoringpoints`.
    // deno-lint-ignore no-explicit-any
    rankingpoints: {[key: string]: (robotinmatch: any) => number}
  };
} = { 2023: season2023, 2024: season2024, 2025: season2025 };

export default dynamicMap;