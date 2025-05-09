import { HttpError, Status } from "@oak/oak";
import dynamicMap from "../data/dynamic/dynamic.ts";

export function validateSeason(
  season: number | null,
): season is keyof typeof dynamicMap {
  return season !== null && season in dynamicMap;
}

export class InvalidSeason extends HttpError<Status.BadRequest> {
  constructor() {
    super(
      `Illegal Arguments: season must be one of ${
        Object.keys(dynamicMap).join(", ")
      }.`,
    );
  }

  override get status(): Status.BadRequest {
    return Status.BadRequest;
  }
}
