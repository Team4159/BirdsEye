import { DBClient } from "../supabase/supabase.ts";
import { avg, normalFit } from "../util.ts";
import dynamicMap from "./dynamic/dynamic.ts";
import { epaMatchup } from "./epa.ts";
import { tba } from "./tba.ts";

const NUM_SIMULATIONS = 100;
// The radius of the band of probabilities considered a tie
const TIE_MARGIN = 0.03;

async function simulateEvent(
  supabase: DBClient,
  season: keyof typeof dynamicMap,
  event: string,
  mostRecentN: number,
) {
  const matches = await tba.getMatches({ season, event });

  const results: Promise<{ [key: string]: number }>[] = [];
  for (let i = 0; i < NUM_SIMULATIONS; i++) {
    const sim = Promise.allSettled(
      matches.map((match): Promise<{ [key: string]: number } | null> =>
        match.comp_level != "qm" ? Promise.resolve(null) : epaMatchup(
          supabase,
          season,
          match.alliances.blue.team_keys.map((t) => t.slice(3)),
          match.alliances.red.team_keys.map((t) => t.slice(3)),
          mostRecentN,
        ).then(
          (
            { blue: blu, red, isMissingData },
          ) => {
            if (isMissingData) return null;
            let blurp = 0;
            let redrp = 0;

            const sample = Math.random() + TIE_MARGIN;
            if (blu.winChance! > sample) {
              blurp += 3;
            } else if (red.winChance! > sample) {
              redrp += 3;
            } else {
              blurp += 1;
              redrp += 1;
            }

            for (const rp of Object.values(blu.rp!)) {
              if (rp > Math.random()) blurp++;
            }
            for (const rp of Object.values(red.rp!)) {
              if (rp > Math.random()) redrp++;
            }

            const blurpteams = blu.teams!;
            for (let teamkey of match.alliances.blue.surrogate_team_keys) {
              teamkey = teamkey.slice(3);
              const i = blurpteams.indexOf(teamkey);
              i !== -1 && blurpteams.splice(i, 1);
            }

            const redrpteams = red.teams!;
            for (let teamkey of match.alliances.red.surrogate_team_keys) {
              teamkey = teamkey.slice(3);
              const i = redrpteams.indexOf(teamkey);
              i !== -1 && redrpteams.splice(i, 1);
            }

            return Object.fromEntries([
              ...blurpteams.map((t) => [t, blurp]),
              ...redrpteams.map((t) => [t, redrp]),
            ]);
          },
        )
      ),
    ).then((results) => {
      const teams: { [key: string]: number[] } = {}; // team: matchrp[]
      for (const result of results) {
        if (!("value" in result) || result.value == null) continue;
        for (const [team, rp] of Object.entries(result.value)) {
          teams[team] ??= [];
          teams[team].push(rp);
        }
      }

      return Object.fromEntries(
        Object.entries(teams).map((
          [k, v],
        ) => [k, avg(v)]),
      );
    });
    results.push(sim);
  }

  const outcomes: { [key: string]: number }[] = [];
  for (const sim of await Promise.allSettled(results)) {
    if (!("value" in sim)) continue;
    outcomes.push(sim.value);
  }
  return outcomes;
}

export async function predictEvent(
  supabase: DBClient,
  season: keyof typeof dynamicMap,
  event: string,
  mostRecentN: number,
) {
  const outcomes = await simulateEvent(supabase, season, event, mostRecentN);

  const teamRanks: { [key: string]: number[] } = {};
  for (const outcome of outcomes) {
    const ranking = Object.entries(outcome).sort(([_a, arp], [_b, brp]) =>
      arp - brp
    ).map(([t, _trp]) => t);
    for (const [rank, team] of ranking.entries()) {
      teamRanks[team] ??= [];
      teamRanks[team].push(rank + 1);
    }
  }

  return Object.fromEntries(
    Object.entries(teamRanks).map(([team, ranks]) => [team, normalFit(ranks)]),
  );
}
