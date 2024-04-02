export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      achievement_queue: {
        Row: {
          achievement: number
          approved: boolean | null
          created_at: string
          details: string | null
          event: string
          season: number
          user: string
        }
        Insert: {
          achievement: number
          approved?: boolean | null
          created_at?: string
          details?: string | null
          event: string
          season: number
          user?: string
        }
        Update: {
          achievement?: number
          approved?: boolean | null
          created_at?: string
          details?: string | null
          event?: string
          season?: number
          user?: string
        }
        Relationships: [
          {
            foreignKeyName: "achievement_queue_achievement_fkey"
            columns: ["achievement"]
            isOneToOne: false
            referencedRelation: "achievements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_queue_user_fkey"
            columns: ["user"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      achievements: {
        Row: {
          description: string
          event: string | null
          id: number
          name: string
          points: number
          requirements: string
          season: number | null
        }
        Insert: {
          description: string
          event?: string | null
          id?: number
          name: string
          points: number
          requirements: string
          season?: number | null
        }
        Update: {
          description?: string
          event?: string | null
          id?: number
          name?: string
          points?: number
          requirements?: string
          season?: number | null
        }
        Relationships: []
      }
      match_data_2023: {
        Row: {
          auto_cone_high: number | null
          auto_cone_low: number | null
          auto_cone_mid: number | null
          auto_cone_misses: number | null
          auto_cube_high: number | null
          auto_cube_low: number | null
          auto_cube_mid: number | null
          auto_cube_misses: number | null
          comments_defensive: boolean | null
          comments_fouls: number | null
          id: number
          teleop_cone_high: number | null
          teleop_cone_low: number | null
          teleop_cone_mid: number | null
          teleop_cone_misses: number | null
          teleop_cube_high: number | null
          teleop_cube_low: number | null
          teleop_cube_mid: number | null
          teleop_cube_misses: number | null
          teleop_intakes_double: number | null
          teleop_intakes_single: number | null
        }
        Insert: {
          auto_cone_high?: number | null
          auto_cone_low?: number | null
          auto_cone_mid?: number | null
          auto_cone_misses?: number | null
          auto_cube_high?: number | null
          auto_cube_low?: number | null
          auto_cube_mid?: number | null
          auto_cube_misses?: number | null
          comments_defensive?: boolean | null
          comments_fouls?: number | null
          id: number
          teleop_cone_high?: number | null
          teleop_cone_low?: number | null
          teleop_cone_mid?: number | null
          teleop_cone_misses?: number | null
          teleop_cube_high?: number | null
          teleop_cube_low?: number | null
          teleop_cube_mid?: number | null
          teleop_cube_misses?: number | null
          teleop_intakes_double?: number | null
          teleop_intakes_single?: number | null
        }
        Update: {
          auto_cone_high?: number | null
          auto_cone_low?: number | null
          auto_cone_mid?: number | null
          auto_cone_misses?: number | null
          auto_cube_high?: number | null
          auto_cube_low?: number | null
          auto_cube_mid?: number | null
          auto_cube_misses?: number | null
          comments_defensive?: boolean | null
          comments_fouls?: number | null
          id?: number
          teleop_cone_high?: number | null
          teleop_cone_low?: number | null
          teleop_cone_mid?: number | null
          teleop_cone_misses?: number | null
          teleop_cube_high?: number | null
          teleop_cube_low?: number | null
          teleop_cube_mid?: number | null
          teleop_cube_misses?: number | null
          teleop_intakes_double?: number | null
          teleop_intakes_single?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "public_2023_match_id_fkey"
            columns: ["id"]
            isOneToOne: false
            referencedRelation: "match_scouting"
            referencedColumns: ["id"]
          },
        ]
      }
      match_data_2024: {
        Row: {
          auto_amp: number
          auto_amp_missed: number
          auto_speaker: number
          auto_speaker_missed: number
          comments_agility: number
          comments_contribution: number
          comments_defensive: boolean
          comments_fouls: number
          id: number
          teleop_amp: number
          teleop_amp_missed: number
          teleop_loudspeaker: number
          teleop_speaker: number
          teleop_speaker_missed: number
          teleop_trap: number
        }
        Insert: {
          auto_amp?: number
          auto_amp_missed?: number
          auto_speaker?: number
          auto_speaker_missed?: number
          comments_agility: number
          comments_contribution: number
          comments_defensive: boolean
          comments_fouls?: number
          id: number
          teleop_amp?: number
          teleop_amp_missed?: number
          teleop_loudspeaker?: number
          teleop_speaker?: number
          teleop_speaker_missed?: number
          teleop_trap?: number
        }
        Update: {
          auto_amp?: number
          auto_amp_missed?: number
          auto_speaker?: number
          auto_speaker_missed?: number
          comments_agility?: number
          comments_contribution?: number
          comments_defensive?: boolean
          comments_fouls?: number
          id?: number
          teleop_amp?: number
          teleop_amp_missed?: number
          teleop_loudspeaker?: number
          teleop_speaker?: number
          teleop_speaker_missed?: number
          teleop_trap?: number
        }
        Relationships: [
          {
            foreignKeyName: "public_2024_match_id_fkey"
            columns: ["id"]
            isOneToOne: true
            referencedRelation: "match_scouting"
            referencedColumns: ["id"]
          },
        ]
      }
      match_scouting: {
        Row: {
          created_at: string
          event: string
          id: number
          match: string
          scouter: string
          season: number
          team: string
        }
        Insert: {
          created_at?: string
          event: string
          id?: number
          match: string
          scouter?: string
          season: number
          team: string
        }
        Update: {
          created_at?: string
          event?: string
          id?: number
          match?: string
          scouter?: string
          season?: number
          team?: string
        }
        Relationships: [
          {
            foreignKeyName: "public_match_scouting_scouter_fkey"
            columns: ["scouter"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      permissions: {
        Row: {
          achievement_approver: boolean
          economy_manager: boolean
          graph_viewer: boolean
          id: string
          qualitative_analyzer: boolean
        }
        Insert: {
          achievement_approver?: boolean
          economy_manager?: boolean
          graph_viewer?: boolean
          id: string
          qualitative_analyzer?: boolean
        }
        Update: {
          achievement_approver?: boolean
          economy_manager?: boolean
          graph_viewer?: boolean
          id?: string
          qualitative_analyzer?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "permissions_id_fkey"
            columns: ["id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      pit_data_2023: {
        Row: {
          comments_generic: string | null
          driveraccuracy: string | null
          driverproficency: string | null
          driverreaction: string | null
          driverskill: string | null
          event: string
          experiencebuildseason: string | null
          robotcomments: string | null
          scouter: string
          team: number
        }
        Insert: {
          comments_generic?: string | null
          driveraccuracy?: string | null
          driverproficency?: string | null
          driverreaction?: string | null
          driverskill?: string | null
          event: string
          experiencebuildseason?: string | null
          robotcomments?: string | null
          scouter: string
          team: number
        }
        Update: {
          comments_generic?: string | null
          driveraccuracy?: string | null
          driverproficency?: string | null
          driverreaction?: string | null
          driverskill?: string | null
          event?: string
          experiencebuildseason?: string | null
          robotcomments?: string | null
          scouter?: string
          team?: number
        }
        Relationships: [
          {
            foreignKeyName: "public_2023_pit_scouter_fkey"
            columns: ["scouter"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      pit_data_2024: {
        Row: {
          comments_generic: string | null
          driverskill: string | null
          event: string
          experiencebuildseason: string | null
          outreachinitiatives: string | null
          rookieinvolvement: string | null
          scoringstructures: string | null
          scouter: string
          team: number
        }
        Insert: {
          comments_generic?: string | null
          driverskill?: string | null
          event: string
          experiencebuildseason?: string | null
          outreachinitiatives?: string | null
          rookieinvolvement?: string | null
          scoringstructures?: string | null
          scouter?: string
          team: number
        }
        Update: {
          comments_generic?: string | null
          driverskill?: string | null
          event?: string
          experiencebuildseason?: string | null
          outreachinitiatives?: string | null
          rookieinvolvement?: string | null
          scoringstructures?: string | null
          scouter?: string
          team?: number
        }
        Relationships: [
          {
            foreignKeyName: "public_2024_pit_scouter_fkey"
            columns: ["scouter"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      sessions: {
        Row: {
          event: string
          match: string | null
          scouter: string
          season: number
          team: string | null
          updated: string
        }
        Insert: {
          event: string
          match?: string | null
          scouter?: string
          season: number
          team?: string | null
          updated?: string
        }
        Update: {
          event?: string
          match?: string | null
          scouter?: string
          season?: number
          team?: string | null
          updated?: string
        }
        Relationships: [
          {
            foreignKeyName: "sessions_scouter_fkey"
            columns: ["scouter"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      users: {
        Row: {
          created_at: string | null
          id: string
          name: string
          team: number
          updated: string | null
        }
        Insert: {
          created_at?: string | null
          id: string
          name?: string
          team: number
          updated?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          name?: string
          team?: number
          updated?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "users_id_fkey"
            columns: ["id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      getavailableseasons: {
        Args: Record<PropertyKey, never>
        Returns: number[]
      }
      gettableschema: {
        Args: {
          tablename: string
        }
        Returns: Json
      }
      ping: {
        Args: Record<PropertyKey, never>
        Returns: string
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type PublicSchema = Database[Extract<keyof Database, "public">]

export type Tables<
  PublicTableNameOrOptions extends
    | keyof (PublicSchema["Tables"] & PublicSchema["Views"])
    | { schema: keyof Database },
  TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof (Database[PublicTableNameOrOptions["schema"]]["Tables"] &
        Database[PublicTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = PublicTableNameOrOptions extends { schema: keyof Database }
  ? (Database[PublicTableNameOrOptions["schema"]]["Tables"] &
      Database[PublicTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : PublicTableNameOrOptions extends keyof (PublicSchema["Tables"] &
        PublicSchema["Views"])
    ? (PublicSchema["Tables"] &
        PublicSchema["Views"])[PublicTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  PublicTableNameOrOptions extends
    | keyof PublicSchema["Tables"]
    | { schema: keyof Database },
  TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = PublicTableNameOrOptions extends { schema: keyof Database }
  ? Database[PublicTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : PublicTableNameOrOptions extends keyof PublicSchema["Tables"]
    ? PublicSchema["Tables"][PublicTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  PublicTableNameOrOptions extends
    | keyof PublicSchema["Tables"]
    | { schema: keyof Database },
  TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = PublicTableNameOrOptions extends { schema: keyof Database }
  ? Database[PublicTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : PublicTableNameOrOptions extends keyof PublicSchema["Tables"]
    ? PublicSchema["Tables"][PublicTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  PublicEnumNameOrOptions extends
    | keyof PublicSchema["Enums"]
    | { schema: keyof Database },
  EnumName extends PublicEnumNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = PublicEnumNameOrOptions extends { schema: keyof Database }
  ? Database[PublicEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : PublicEnumNameOrOptions extends keyof PublicSchema["Enums"]
    ? PublicSchema["Enums"][PublicEnumNameOrOptions]
    : never
