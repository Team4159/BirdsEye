import { Normal } from "../math.ts";
import { DBClient } from "../supabase/supabase.ts";
import dynamicMap from "./dynamic/dynamic.ts";
import { epaMatchup } from "./epa.ts";
import { tba } from "./tba.ts";

const NUM_SIMULATIONS = 100;
// The radius of the band of probabilities considered a tie
const TIE_MARGIN = 0.04; // 8%

async function simulateEvent(
  supabase: DBClient,
  season: keyof typeof dynamicMap,
  event: string,
  calclimit: number,
  realmatches: number = Number.MAX_SAFE_INTEGER
) {
  const matches = await tba.getMatches({ season, event });

  // [ match: [ simulation: {team: rp} ] ]
  const results = await Promise.allSettled(matches.map(async (match) => {
    // Only simulate qualification matches
    if (match.comp_level !== "qm") return;
    // Don't simulate if real results exist
    if (match.score_breakdown && match.match_number <= realmatches) {
      const out: Record<string, number> = {};
      for (const alliance of Object.values(match.alliances)) {
        for (const surrogate of alliance.surrogate_team_keys) {
          const i = alliance.team_keys.indexOf(surrogate);
          if (i === -1) continue;
          alliance.team_keys.splice(i, 1);
        }
      }
      for (const [alliance, ascore] of Object.entries(match.score_breakdown) as ["red" | "blue", object][]) {
        if (!("rp" in ascore) || typeof ascore["rp"] !== "number") {
          console.warn(`Invalid Score Breakdown for ${match.key}`);
          continue;
        }
        for (const team of match.alliances[alliance].team_keys) {
          out[team.slice(3)] = ascore["rp"];
        }
      }
      // Fill an array with references to out
      return new Array<Record<string, number>>(NUM_SIMULATIONS).fill(out);
    }

    const { blue: blu, red, isMissingData } = await epaMatchup(
      supabase,
      season,
      match.alliances.blue.team_keys.map((t) => t.slice(3)),
      match.alliances.red.team_keys.map((t) => t.slice(3)),
      calclimit,
    );
    
    // Don't simulate with incomplete data
    if (isMissingData) return;

    // Remove surrogates from team lists
    for (let surrogate of match.alliances.blue.surrogate_team_keys) {
      surrogate = surrogate.slice(3);
      const i = blu.teams.indexOf(surrogate);
      if (i === -1) continue;
      blu.teams.splice(i, 1);
    }
    for (let surrogate of match.alliances.red.surrogate_team_keys) {
      surrogate = surrogate.slice(3);
      const i = red.teams.indexOf(surrogate);
      if (i === -1) continue;
      red.teams.splice(i, 1);
    }

    // Run simulations

    // { team: rp }[]
    const sims: Record<string, number>[] = new Array(NUM_SIMULATIONS);
    for (let i = 0; i < NUM_SIMULATIONS; i++) {
      const sample = Math.random();

      // { team: rp }
      const matchaccum: typeof sims[number] = {};
      for (const alliance of [blu, red]) {
        let alliancerp;
        
        if (alliance.winChance > sample + TIE_MARGIN) {
          alliancerp = 3; // win
        } else if (alliance.winChance >= sample - TIE_MARGIN) {
          alliancerp = 1; // tie
        } else {
          alliancerp = 0; // loss
        }
    
        for (const rpchance of Object.values(alliance.rp))
          if (rpchance > Math.random()) alliancerp++;
        
        for (const team of alliance.teams)
          matchaccum[team] = alliancerp;
      }

      sims[i] = matchaccum;
    }

    return sims;
  })).then(res => res
    .filter(promise => promise.status === "fulfilled")
    .map(promise => promise.value)
    .filter(match => match !== undefined)
  );

  // [ simulation: { team: rp[] } ]
  const simulations: Record<string, number[]>[] = new Array(NUM_SIMULATIONS);

  // match is [ simulation: { team: rp } ]
  for (const match of results) {
    for (const [simnum, sim] of match.entries()) {
      for (const [team, rp] of Object.entries(sim)) {
        simulations[simnum] ??= {};
        simulations[simnum]![team] ??= [];
        simulations[simnum]![team].push(rp);
      }
    }
  }
  
  // { team: average rp }[]
  return simulations.map(sim => 
    Object.fromEntries(Object.entries(sim).map(
      ([team, rps]) => [team, rps.reduce((a, b) => a + b, 0) / rps.length]
    ))
  );
}

export async function predictEvent(
  supabase: DBClient,
  season: keyof typeof dynamicMap,
  event: string,
  calclimit: number,
  realmatches?: number
) {
  const outcomes = await simulateEvent(supabase, season, event, calclimit, realmatches);

  const teamRanks: { [key: string]: number[] } = {};
  for (const outcome of outcomes) {
    const ranking = Object.entries(outcome).sort(([_a, arp], [_b, brp]) =>
      brp - arp
    ).map(([t, _trp]) => t);
    for (const [rank, team] of ranking.entries()) {
      teamRanks[team] ??= [];
      teamRanks[team].push(rank + 1);
    }
  }

  return Object.fromEntries(
    Object.entries(teamRanks).map(([team, ranks]) => [team, new Normal(ranks)]),
  );
}