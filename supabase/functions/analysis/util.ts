import stats from "@stdlib/stats-base-dists-normal";
import stdev from "@stdlib/stats-base-stdev";

export type Normal = { mean: number; stdev: number, quantile( p: number ): number; }; // no idea why we need this but we do
// TODO switch to skewed normal distribution

export function avg(x: number[]) {
  return x.length === 0 ? 0 : x.reduce((a, b) => a + b, 0) / x.length;
}
function std(x: number[]) {
  return stdev(x.length, 1, x, 1) || Number.EPSILON; // std cannot be 0, or things get unhappy.
}
export function normalFit(dataset: number[]) {
  return new stats.Normal(avg(dataset), std(dataset));
}

export function normalSum(...terms: Normal[]) {
  return new stats.Normal(
    terms.reduce((t, a) => t + a.mean, 0),
    Math.sqrt(terms.reduce((t, a) => t + a.stdev * a.stdev, 0)),
  );
}

export function normalDifference(
  minuend: Normal,
  subtrahend: Normal,
) {
  return new stats.Normal(
    minuend.mean - subtrahend.mean,
    Math.sqrt(minuend.stdev * minuend.stdev + subtrahend.stdev * subtrahend.stdev),
  );
}

/**
 * Computers a Box-Muller transform to compute a normally distributed random number.
 * @param term The distribution to sample
 * @returns A sample
 */
export function normalSample(term: Normal) {
  const u = 1 - Math.random(); // (0,1]
  const v = Math.random(); // [0,1)
  const z = Math.sqrt( -2.0 * Math.log( u ) ) * Math.cos( 2.0 * Math.PI * v );
  // Transform to the desired mean and standard deviation:
  return z * term.stdev + term.mean;
}

/**
 * Teamwork Sum - How probable a team is to succeed given individual members' chances to succeed.
 * @param x The variable to scale [0, ∞)
 * @returns The scaled variable [0, 1)
 */
export function teamworkSum(x: number): number {
  const intermediate = Math.exp(x) * x;
  return intermediate / (intermediate + 1);
}