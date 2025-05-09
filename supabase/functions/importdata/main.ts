import { parse } from "@std/csv";
import { createClient, SupabaseClient } from "@supabase/supabase-js";

// Initialize Supabase client (configure with your credentials)

async function processData(supabase: SupabaseClient, csvInput: string) {
  const records = parse(csvInput, {skipFirstRow: true});

  for (const record of records) {
    try {
      // Transform match_scouting data
      const matchScoutingData = {
        season: parseInt(record.year),
        event: record.event_key,
        match: record.match_key.split("_")[1], // Extract match identifier
        team: record.team_key.replace("frc", ""),
        created_at: new Date(record.time).toISOString()
      };

      // Insert into match_scouting and get generated ID
      const { data: scoutingData, error: scoutingError } = await supabase
        .from("match_scouting")
        .insert(matchScoutingData)
        .select("id")
        .single();

      if (scoutingError) throw scoutingError;

      // Transform match_data_2025 data
      const matchData = {
        id: scoutingData.id,
        auto_coral_l1: parseInt(record.autoL1),
        auto_coral_l2: parseInt(record.autoL2),
        auto_coral_l3: parseInt(record.autoL3),
        auto_coral_l4: parseInt(record.autoL4),
        auto_algae_processor: parseInt(record.autoProcessor),
        auto_coral_missed: parseInt(record.AutoAlgaeReef),
        auto_algae_net: parseInt(record.autoNet),
        auto_algae_net_missed: parseInt(record.didFeedStation),
        teleop_coral_l1: parseInt(record.teleopL1),
        teleop_coral_l2: Math.min(12, Math.max(0, parseInt(record.teleopL2))),
        teleop_coral_l3: Math.min(12, Math.max(0, parseInt(record.teleopL3))),
        teleop_coral_l4: Math.min(12, Math.max(0, parseInt(record.teleopL4))),
        teleop_algae_processor: parseInt(record.teleopProcessor),
        teleop_coral_missed: parseInt(record.teleopAlgaeReef),
        teleop_algae_net: parseInt(record.teleopNet),
        teleop_algae_net_missed: parseInt(record.teleopAlgaeFloor),
        comments_fouls: parseInt(record.RedCard) + parseInt(record.YellowCard),
        comments_defensive: record.alliance === "red",
        comments_agility: record.endgameBarge === "Parked" ? 5.0 : 0.0,
        auto_coral_intake_failed: record.didStartingZone === "0" ? 1 : 0,
        auto_algae_intake_failed: record.didFeedStation === "0" ? 1 : 0,
        teleop_coral_intake_failed: 0,
        teleop_algae_intake_failed: 0
      };

      // Insert into match_data_2025
      const { error: dataError } = await supabase
        .from("match_data_2025")
        .insert(matchData);

      if (dataError) throw dataError;

      console.log(`Successfully inserted record ID: ${scoutingData.id}`);
    } catch (error) {
      console.error("Error processing record:", error.message);
    }
  }
};