import { getRobotPosition, MatchInfo } from "../tba.ts";

// interface ScoreBreakdown {
//     "adjustPoints": number,
//     "autoAmpNoteCount": number,
//     "autoAmpNotePoints": number,
//     "autoLeavePoints": number,
//     "autoLineRobot1": "Yes" | "No",
//     "autoLineRobot2": "Yes" | "No",
//     "autoLineRobot3": "Yes" | "No",
//     "autoPoints": number,
//     "autoSpeakerNoteCount": number,
//     "autoSpeakerNotePoints": number,
//     "autoTotalNotePoints": number,
//     "coopNotePlayed": boolean,
//     "coopertitionBonusAchieved": boolean,
//     "coopertitionCriteriaMet": boolean,
//     "endGameHarmonyPoints": number,
//     "endGameNoteInTrapPoints": number,
//     "endGameOnStagePoints": number,
//     "endGameParkPoints": number,
//     "endGameRobot1": "None" | "Parked" | "StageLeft" | "StageRight" | "CenterStage",
//     "endGameRobot2": "None" | "Parked" | "StageLeft" | "StageRight" | "CenterStage",
//     "endGameRobot3": "None" | "Parked" | "StageLeft" | "StageRight" | "CenterStage",
//     "endGameSpotLightBonusPoints": number,
//     "endGameTotalStagePoints": number,
//     "ensembleBonusAchieved": boolean,
//     "ensembleBonusOnStageRobotsThreshold": number,
//     "ensembleBonusStagePointsThreshold": number,
//     "foulCount": number,
//     "foulPoints": number,
//     "g206Penalty": boolean,
//     "g408Penalty": boolean,
//     "g424Penalty": boolean,
//     "melodyBonusAchieved": boolean,
//     "melodyBonusThreshold": number,
//     "melodyBonusThresholdCoop": number,
//     "melodyBonusThresholdNonCoop": number,
//     "micCenterStage": boolean,
//     "micStageLeft": boolean,
//     "micStageRight": boolean,
//     "rp": number,
//     "techFoulCount": number,
//     "teleopAmpNoteCount": number,
//     "teleopAmpNotePoints": number,
//     "teleopPoints": number,
//     "teleopSpeakerNoteAmplifiedCount": number,
//     "teleopSpeakerNoteAmplifiedPoints": number,
//     "teleopSpeakerNoteCount": number,
//     "teleopSpeakerNotePoints": number,
//     "teleopTotalNotePoints": number,
//     "totalPoints": number,
//     "trapCenterStage": boolean,
//     "trapStageLeft": boolean,
//     "trapStageRight": boolean
// }

export const dbtable = "match_data_2024";
export const dbcolumns = [
  "auto_amp",
  "auto_amp_missed",
  "auto_speaker",
  "auto_speaker_missed",
  "teleop_amp",
  "teleop_amp_missed",
  "teleop_speaker",
  "teleop_loudspeaker",
  "teleop_speaker_missed",
  "teleop_trap",
  "comments_fouls",
  "comments_defense",
  "comments_agility",
  "comments_contribution",
]

export function fuseData(
  dbdata: { [key: string]: number },
  robot: string,
  tbamatch: MatchInfo,
): { [key: string]: number } {
  const { alliance, index } = getRobotPosition(tbamatch.alliances, robot);
  // deno-lint-ignore no-explicit-any
  const scoreBreak: { [key: string]: any } = tbamatch.score_breakdown[alliance];

  dbdata["endgame_trap"] = dbdata["teleop_trap"] ?? 0;
  delete dbdata["teleop_trap"];

  dbdata["auto_leave"] = scoreBreak[`autoLineRobot${index}`] === "Yes" ? 1 : 0;
  dbdata["endgame_parked"] = dbdata["endgame_onstage"] = dbdata["endgame_spotlit"] = 0;
  const parkstatus = scoreBreak[`endGameRobot${index}`];
  switch (parkstatus) {
    case "None":
      break;
    case "Parked":
      dbdata["endgame_parked"] = 1;
      break;
    default: {
      const highNotes = Object.entries(scoreBreak)
        .filter(([k, v]) => k.startsWith("mic") && v)
        .map(([k, _]) => k.slice(3));
      if (highNotes.includes(parkstatus)) dbdata["endgame_spotlit"] = 1;
      else dbdata["endgame_onstage"] = 1;
      break;
    }
  }

  return dbdata;
}

export const scoringpoints = {
  "auto_amp": 5,
  "auto_speaker": 5,
  "teleop_amp": 1,
  "teleop_speaker": 2,
  "teleop_loudspeaker": 5,
  "endgame_trap": 5,
  "endgame_parked": 1,
  "endgame_onstage": 3,
  "endgame_spotlit": 4,
  "comments_fouls": -2,
};

export const scoringelements = ["amp", "speaker", "endgame"]

export const rankingpoints: {[key: string]: (robotinmatch: typeof scoringpoints) => number} = {
  melody(rim) {
    let sum = 0;
    const objectives = ["auto_amp", "auto_speaker", "teleop_amp", "teleop_speaker", "teleop_loudspeaker"] as (keyof typeof scoringpoints)[];
    for (const objective of objectives) {
      sum += rim[objective] * scoringpoints[objective];
    }
    return Math.min(sum / 18, 1) // ignores coop
  },
  ensemble(rim) {
    let sum = 0;
    const objectives = Object.keys(scoringpoints).filter(o => o.startsWith("endgame_")) as (keyof typeof scoringpoints)[];
    for (const objective of objectives) {
      sum += rim[objective] * scoringpoints[objective];
    }
    return Math.min(sum / 10, 0.5) + rim.endgame_onstage / 4
  }
}