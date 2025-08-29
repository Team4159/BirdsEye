export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "12.2.3 (519615d)"
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
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
            foreignKeyName: "match_data_2023_id_fkey"
            columns: ["id"]
            isOneToOne: true
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
            foreignKeyName: "match_data_2024_id_fkey"
            columns: ["id"]
            isOneToOne: true
            referencedRelation: "match_scouting"
            referencedColumns: ["id"]
          },
        ]
      }
      match_data_2025: {
        Row: {
          auto_algae_intake_failed: number | null
          auto_algae_net: number
          auto_algae_net_missed: number
          auto_algae_processor: number
          auto_coral_intake_failed: number | null
          auto_coral_l1: number
          auto_coral_l2: number
          auto_coral_l3: number
          auto_coral_l4: number
          auto_coral_missed: number
          comments_agility: number | null
          comments_defensive: boolean
          comments_fouls: number
          id: number
          teleop_algae_intake_failed: number | null
          teleop_algae_net: number
          teleop_algae_net_missed: number
          teleop_algae_processor: number
          teleop_coral_intake_failed: number | null
          teleop_coral_l1: number
          teleop_coral_l2: number
          teleop_coral_l3: number
          teleop_coral_l4: number
          teleop_coral_missed: number
        }
        Insert: {
          auto_algae_intake_failed?: number | null
          auto_algae_net: number
          auto_algae_net_missed: number
          auto_algae_processor: number
          auto_coral_intake_failed?: number | null
          auto_coral_l1: number
          auto_coral_l2: number
          auto_coral_l3: number
          auto_coral_l4: number
          auto_coral_missed: number
          comments_agility?: number | null
          comments_defensive: boolean
          comments_fouls: number
          id?: number
          teleop_algae_intake_failed?: number | null
          teleop_algae_net: number
          teleop_algae_net_missed: number
          teleop_algae_processor: number
          teleop_coral_intake_failed?: number | null
          teleop_coral_l1: number
          teleop_coral_l2: number
          teleop_coral_l3: number
          teleop_coral_l4: number
          teleop_coral_missed: number
        }
        Update: {
          auto_algae_intake_failed?: number | null
          auto_algae_net?: number
          auto_algae_net_missed?: number
          auto_algae_processor?: number
          auto_coral_intake_failed?: number | null
          auto_coral_l1?: number
          auto_coral_l2?: number
          auto_coral_l3?: number
          auto_coral_l4?: number
          auto_coral_missed?: number
          comments_agility?: number | null
          comments_defensive?: boolean
          comments_fouls?: number
          id?: number
          teleop_algae_intake_failed?: number | null
          teleop_algae_net?: number
          teleop_algae_net_missed?: number
          teleop_algae_processor?: number
          teleop_coral_intake_failed?: number | null
          teleop_coral_l1?: number
          teleop_coral_l2?: number
          teleop_coral_l3?: number
          teleop_coral_l4?: number
          teleop_coral_missed?: number
        }
        Relationships: [
          {
            foreignKeyName: "match_data_2025_id_fkey"
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
          match_code: number
          scouter: string
          season: number
          team: string
        }
        Insert: {
          created_at?: string
          event: string
          id?: number
          match: string
          match_code?: number
          scouter?: string
          season: number
          team: string
        }
        Update: {
          created_at?: string
          event?: string
          id?: number
          match?: string
          match_code?: number
          scouter?: string
          season?: number
          team?: string
        }
        Relationships: [
          {
            foreignKeyName: "match_scouting_scouter_fkey"
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
          pit_viewer: boolean
        }
        Insert: {
          achievement_approver?: boolean
          economy_manager?: boolean
          graph_viewer?: boolean
          id: string
          pit_viewer?: boolean
        }
        Update: {
          achievement_approver?: boolean
          economy_manager?: boolean
          graph_viewer?: boolean
          id?: string
          pit_viewer?: boolean
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
      pit_questions: {
        Row: {
          id: string
          question: string
        }
        Insert: {
          id: string
          question: string
        }
        Update: {
          id?: string
          question?: string
        }
        Relationships: []
      }
      pit_scouting: {
        Row: {
          data: Json
          event: string
          scouter: string
          season: number
          team: number
          updated: string
        }
        Insert: {
          data: Json
          event: string
          scouter?: string
          season: number
          team: number
          updated?: string
        }
        Update: {
          data?: Json
          event?: string
          scouter?: string
          season?: number
          team?: number
          updated?: string
        }
        Relationships: [
          {
            foreignKeyName: "pit_scouting_scouter_fkey"
            columns: ["scouter"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      pit_seasons: {
        Row: {
          qid: string
          season: number
        }
        Insert: {
          qid: string
          season: number
        }
        Update: {
          qid?: string
          season?: number
        }
        Relationships: [
          {
            foreignKeyName: "pit_seasons_qid_fkey"
            columns: ["qid"]
            isOneToOne: false
            referencedRelation: "pit_questions"
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
        Relationships: []
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
      getpitschema: {
        Args: { pitseason: number }
        Returns: Json
      }
      gettableschema: {
        Args: { tablename: string }
        Returns: Json
      }
      match_code: {
        Args: { match: string }
        Returns: number
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
  storage: {
    Tables: {
      buckets: {
        Row: {
          allowed_mime_types: string[] | null
          avif_autodetection: boolean | null
          created_at: string | null
          file_size_limit: number | null
          id: string
          name: string
          owner: string | null
          owner_id: string | null
          public: boolean | null
          updated_at: string | null
        }
        Insert: {
          allowed_mime_types?: string[] | null
          avif_autodetection?: boolean | null
          created_at?: string | null
          file_size_limit?: number | null
          id: string
          name: string
          owner?: string | null
          owner_id?: string | null
          public?: boolean | null
          updated_at?: string | null
        }
        Update: {
          allowed_mime_types?: string[] | null
          avif_autodetection?: boolean | null
          created_at?: string | null
          file_size_limit?: number | null
          id?: string
          name?: string
          owner?: string | null
          owner_id?: string | null
          public?: boolean | null
          updated_at?: string | null
        }
        Relationships: []
      }
      migrations: {
        Row: {
          executed_at: string | null
          hash: string
          id: number
          name: string
        }
        Insert: {
          executed_at?: string | null
          hash: string
          id: number
          name: string
        }
        Update: {
          executed_at?: string | null
          hash?: string
          id?: number
          name?: string
        }
        Relationships: []
      }
      objects: {
        Row: {
          bucket_id: string | null
          created_at: string | null
          id: string
          last_accessed_at: string | null
          metadata: Json | null
          name: string | null
          owner: string | null
          owner_id: string | null
          path_tokens: string[] | null
          updated_at: string | null
          user_metadata: Json | null
          version: string | null
        }
        Insert: {
          bucket_id?: string | null
          created_at?: string | null
          id?: string
          last_accessed_at?: string | null
          metadata?: Json | null
          name?: string | null
          owner?: string | null
          owner_id?: string | null
          path_tokens?: string[] | null
          updated_at?: string | null
          user_metadata?: Json | null
          version?: string | null
        }
        Update: {
          bucket_id?: string | null
          created_at?: string | null
          id?: string
          last_accessed_at?: string | null
          metadata?: Json | null
          name?: string | null
          owner?: string | null
          owner_id?: string | null
          path_tokens?: string[] | null
          updated_at?: string | null
          user_metadata?: Json | null
          version?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "objects_bucketId_fkey"
            columns: ["bucket_id"]
            isOneToOne: false
            referencedRelation: "buckets"
            referencedColumns: ["id"]
          },
        ]
      }
      s3_multipart_uploads: {
        Row: {
          bucket_id: string
          created_at: string
          id: string
          in_progress_size: number
          key: string
          owner_id: string | null
          upload_signature: string
          user_metadata: Json | null
          version: string
        }
        Insert: {
          bucket_id: string
          created_at?: string
          id: string
          in_progress_size?: number
          key: string
          owner_id?: string | null
          upload_signature: string
          user_metadata?: Json | null
          version: string
        }
        Update: {
          bucket_id?: string
          created_at?: string
          id?: string
          in_progress_size?: number
          key?: string
          owner_id?: string | null
          upload_signature?: string
          user_metadata?: Json | null
          version?: string
        }
        Relationships: [
          {
            foreignKeyName: "s3_multipart_uploads_bucket_id_fkey"
            columns: ["bucket_id"]
            isOneToOne: false
            referencedRelation: "buckets"
            referencedColumns: ["id"]
          },
        ]
      }
      s3_multipart_uploads_parts: {
        Row: {
          bucket_id: string
          created_at: string
          etag: string
          id: string
          key: string
          owner_id: string | null
          part_number: number
          size: number
          upload_id: string
          version: string
        }
        Insert: {
          bucket_id: string
          created_at?: string
          etag: string
          id?: string
          key: string
          owner_id?: string | null
          part_number: number
          size?: number
          upload_id: string
          version: string
        }
        Update: {
          bucket_id?: string
          created_at?: string
          etag?: string
          id?: string
          key?: string
          owner_id?: string | null
          part_number?: number
          size?: number
          upload_id?: string
          version?: string
        }
        Relationships: [
          {
            foreignKeyName: "s3_multipart_uploads_parts_bucket_id_fkey"
            columns: ["bucket_id"]
            isOneToOne: false
            referencedRelation: "buckets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "s3_multipart_uploads_parts_upload_id_fkey"
            columns: ["upload_id"]
            isOneToOne: false
            referencedRelation: "s3_multipart_uploads"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      can_insert_object: {
        Args: { bucketid: string; metadata: Json; name: string; owner: string }
        Returns: undefined
      }
      extension: {
        Args: { name: string }
        Returns: string
      }
      filename: {
        Args: { name: string }
        Returns: string
      }
      foldername: {
        Args: { name: string }
        Returns: string[]
      }
      get_size_by_bucket: {
        Args: Record<PropertyKey, never>
        Returns: {
          bucket_id: string
          size: number
        }[]
      }
      list_multipart_uploads_with_delimiter: {
        Args: {
          bucket_id: string
          delimiter_param: string
          max_keys?: number
          next_key_token?: string
          next_upload_token?: string
          prefix_param: string
        }
        Returns: {
          created_at: string
          id: string
          key: string
        }[]
      }
      list_objects_with_delimiter: {
        Args: {
          bucket_id: string
          delimiter_param: string
          max_keys?: number
          next_token?: string
          prefix_param: string
          start_after?: string
        }
        Returns: {
          id: string
          metadata: Json
          name: string
          updated_at: string
        }[]
      }
      operation: {
        Args: Record<PropertyKey, never>
        Returns: string
      }
      search: {
        Args: {
          bucketname: string
          levels?: number
          limits?: number
          offsets?: number
          prefix: string
          search?: string
          sortcolumn?: string
          sortorder?: string
        }
        Returns: {
          created_at: string
          id: string
          last_accessed_at: string
          metadata: Json
          name: string
          updated_at: string
        }[]
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

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
  storage: {
    Enums: {},
  },
} as const
