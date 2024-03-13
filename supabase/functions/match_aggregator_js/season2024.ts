import { MatchInfo, getRobotPosition } from "./tba.types.ts";

interface ScoreBreakdown {
    "adjustPoints": number,
    "autoAmpNoteCount": number,
    "autoAmpNotePoints": number,
    "autoLeavePoints": number,
    "autoLineRobot1": "Yes" | "No",
    "autoLineRobot2": "Yes" | "No",
    "autoLineRobot3": "Yes" | "No",
    "autoPoints": number,
    "autoSpeakerNoteCount": number,
    "autoSpeakerNotePoints": number,
    "autoTotalNotePoints": number,
    "coopNotePlayed": boolean,
    "coopertitionBonusAchieved": boolean,
    "coopertitionCriteriaMet": boolean,
    "endGameHarmonyPoints": number,
    "endGameNoteInTrapPoints": number,
    "endGameOnStagePoints": number,
    "endGameParkPoints": number,
    "endGameRobot1": "None" | "Parked" | "StageLeft" | "StageRight" | "CenterStage",
    "endGameRobot2": "None" | "Parked" | "StageLeft" | "StageRight" | "CenterStage",
    "endGameRobot3": "None" | "Parked" | "StageLeft" | "StageRight" | "CenterStage",
    "endGameSpotLightBonusPoints": number,
    "endGameTotalStagePoints": number,
    "ensembleBonusAchieved": boolean,
    "ensembleBonusOnStageRobotsThreshold": number,
    "ensembleBonusStagePointsThreshold": number,
    "foulCount": number,
    "foulPoints": number,
    "g206Penalty": boolean,
    "g408Penalty": boolean,
    "g424Penalty": boolean,
    "melodyBonusAchieved": boolean,
    "melodyBonusThreshold": number,
    "melodyBonusThresholdCoop": number,
    "melodyBonusThresholdNonCoop": number,
    "micCenterStage": boolean,
    "micStageLeft": boolean,
    "micStageRight": boolean,
    "rp": number,
    "techFoulCount": number,
    "teleopAmpNoteCount": number,
    "teleopAmpNotePoints": number,
    "teleopPoints": number,
    "teleopSpeakerNoteAmplifiedCount": number,
    "teleopSpeakerNoteAmplifiedPoints": number,
    "teleopSpeakerNoteCount": number,
    "teleopSpeakerNotePoints": number,
    "teleopTotalNotePoints": number,
    "totalPoints": number,
    "trapCenterStage": boolean,
    "trapStageLeft": boolean,
    "trapStageRight": boolean  
}

export default function (
    teamdata: { [key: string]: Set<number> },
    team: string,
    tbamatch: MatchInfo,
  ) {
    const { alliance, index } = getRobotPosition(tbamatch.alliances, team);
    // deno-lint-ignore no-explicit-any
    const scoreBreak: { [key: string]: any } = tbamatch.score_breakdown[alliance];

    teamdata["auto_leave"] = new Set([scoreBreak[`autoLineRobot${index}`] === "Yes" ? 1 : 0]);
    let f: number[];

    f = [...teamdata["auto_amp"]].filter(n => n <= scoreBreak["autoAmpNoteCount"]);
    teamdata["auto_amp"] = new Set(f.length === 0 ? [scoreBreak["autoAmpNoteCount"]] : f);

    f = [...teamdata["auto_speaker"]].filter(n => n <= scoreBreak["autoSpeakerNoteCount"]);
    teamdata["auto_speaker"] = new Set(f.length === 0 ? [scoreBreak["autoSpeakerNoteCount"]] : f);

    f = [...teamdata["teleop_amp"]].filter(n => n <= scoreBreak["teleopAmpNoteCount"]);
    teamdata["teleop_amp"] = new Set(f.length === 0 ? [scoreBreak["teleopAmpNoteCount"]] : f);

    f = [...teamdata["teleop_speaker"]].filter(n => n <= scoreBreak["teleopSpeakerNoteCount"]);
    teamdata["teleop_speaker"] = new Set(f.length === 0 ? [scoreBreak["teleopSpeakerNoteCount"]] : f);

    f = [...teamdata["teleop_loudspeaker"]].filter(n => n <= scoreBreak["teleopSpeakerNoteAmplifiedCount"]);
    teamdata["teleop_loudspeaker"] = new Set(f.length === 0 ? [scoreBreak["teleopSpeakerNoteAmplifiedCount"]] : f);

    teamdata["endgame_trap"] = teamdata["teleop_trap"];
    delete teamdata["teleop_trap"];

    const parkstatus = scoreBreak[`endGameRobot${index}`];
    if (parkstatus === "None") return;
    if (parkstatus === "Parked") {teamdata["endgame_parked"] = new Set([1]); return;}
    const highNotes = Object.entries(scoreBreak).filter(([k, v]) => k.startsWith("mic") && v).map(([k, _]) => k.slice(3))
    if (highNotes.includes(parkstatus)) teamdata["endgame_spotlit"] = new Set([1])
    else teamdata["endgame_onstage"] = new Set([1])
  }
  