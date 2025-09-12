import * as ss from "simple-statistics";

// TODO switch to skewed normal distribution
export class Normal {
  readonly mean: number;
  readonly variance: number;

  constructor(params: { mean: number; variance: number } | readonly number[]) {
    if ("mean" in params) {
      if (params.variance < 0) throw Error("variance must be >0");
      this.mean = params.mean;
      this.variance = params.variance;
    } else {
      if (params.length === 1) {
        this.mean = params[0]!;
        this.variance = 0;
      } else {
        this.mean = ss.meanSimple(params as number[]);
        this.variance = ss.variance(params as number[]);
      }
    }
  }

  public cdf(x: number): number {
    if (Number.isNaN(x)) return NaN;

    if (this.variance === 0)
      return (x < this.mean) ? 0.0 : 1.0;

    return 0.5 * (1 + ss.erf((x - this.mean) / (Math.sqrt(this.variance) * Math.SQRT2)));
  }

  public static sum(...terms: readonly Normal[]) {
    return new Normal(
      {
        mean: terms.reduce((t, a) => t + a.mean, 0),
        variance: terms.reduce((t, a) => t + a.variance, 0),
      },
    );
  }

  public static difference(
    minuend: Normal,
    subtrahend: Normal,
  ) {
    return new Normal(
      {
        mean: minuend.mean - subtrahend.mean,
        variance: minuend.variance + subtrahend.variance,
      },
    );
  }
}

/**
 * Teamwork Sum - How likely a team is to succeed given individual members' chances to succeed.
 * @param x The variable (raw sum) to scale [0, ∞)
 * @returns The scaled variable [0, 1)
 */
export function teamworkSum(x: number): number {
  const intermediate = Math.exp(x) * x;
  return intermediate / (intermediate + 1);
}
