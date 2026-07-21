export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
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
      almanac_days: {
        Row: {
          festival_ids: string[]
          has_major: boolean
          is_leap_month: boolean
          is_zhai_ten: boolean
          lunar_day: number
          lunar_month: number
          names_hans: string[]
          names_hant: string[]
          solar_date: string
        }
        Insert: {
          festival_ids?: string[]
          has_major?: boolean
          is_leap_month?: boolean
          is_zhai_ten?: boolean
          lunar_day: number
          lunar_month: number
          names_hans?: string[]
          names_hant?: string[]
          solar_date: string
        }
        Update: {
          festival_ids?: string[]
          has_major?: boolean
          is_leap_month?: boolean
          is_zhai_ten?: boolean
          lunar_day?: number
          lunar_month?: number
          names_hans?: string[]
          names_hant?: string[]
          solar_date?: string
        }
        Relationships: []
      }
      app_secrets: {
        Row: {
          key: string
          updated_at: string
          value: string
        }
        Insert: {
          key: string
          updated_at?: string
          value: string
        }
        Update: {
          key?: string
          updated_at?: string
          value?: string
        }
        Relationships: []
      }
      app_settings: {
        Row: {
          key: string
          updated_at: string
          value: string
        }
        Insert: {
          key: string
          updated_at?: string
          value: string
        }
        Update: {
          key?: string
          updated_at?: string
          value?: string
        }
        Relationships: []
      }
      event_agenda_items: {
        Row: {
          activity: string
          created_at: string
          day_index: number
          end_time: string | null
          event_id: string
          id: string
          link_label: string | null
          link_url: string | null
          sort_order: number
          start_time: string
        }
        Insert: {
          activity: string
          created_at?: string
          day_index?: number
          end_time?: string | null
          event_id: string
          id?: string
          link_label?: string | null
          link_url?: string | null
          sort_order?: number
          start_time: string
        }
        Update: {
          activity?: string
          created_at?: string
          day_index?: number
          end_time?: string | null
          event_id?: string
          id?: string
          link_label?: string | null
          link_url?: string | null
          sort_order?: number
          start_time?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_agenda_items_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      event_attachments: {
        Row: {
          content_type: string | null
          created_at: string
          event_id: string
          id: string
          size_bytes: number | null
          sort_order: number
          storage_path: string
          title: string
        }
        Insert: {
          content_type?: string | null
          created_at?: string
          event_id: string
          id?: string
          size_bytes?: number | null
          sort_order?: number
          storage_path: string
          title: string
        }
        Update: {
          content_type?: string | null
          created_at?: string
          event_id?: string
          id?: string
          size_bytes?: number | null
          sort_order?: number
          storage_path?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_attachments_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      event_overrides: {
        Row: {
          event_id: string
          occurrence_date: string
          patch: Json
        }
        Insert: {
          event_id: string
          occurrence_date: string
          patch?: Json
        }
        Update: {
          event_id?: string
          occurrence_date?: string
          patch?: Json
        }
        Relationships: [
          {
            foreignKeyName: "event_overrides_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      event_types: {
        Row: {
          active: boolean
          icon: string
          id: string
          name_hans: string
          name_hant: string
          sort_order: number
        }
        Insert: {
          active?: boolean
          icon?: string
          id?: string
          name_hans: string
          name_hant: string
          sort_order?: number
        }
        Update: {
          active?: boolean
          icon?: string
          id?: string
          name_hans?: string
          name_hant?: string
          sort_order?: number
        }
        Relationships: []
      }
      events: {
        Row: {
          content: string | null
          created_at: string
          created_by: string | null
          duration_minutes: number | null
          event_type_id: string
          id: string
          recurrence_rule: string | null
          start_at: string
          timezone: string
          title: string
          webex_url: string | null
          youtube_url: string | null
        }
        Insert: {
          content?: string | null
          created_at?: string
          created_by?: string | null
          duration_minutes?: number | null
          event_type_id: string
          id?: string
          recurrence_rule?: string | null
          start_at: string
          timezone?: string
          title: string
          webex_url?: string | null
          youtube_url?: string | null
        }
        Update: {
          content?: string | null
          created_at?: string
          created_by?: string | null
          duration_minutes?: number | null
          event_type_id?: string
          id?: string
          recurrence_rule?: string | null
          start_at?: string
          timezone?: string
          title?: string
          webex_url?: string | null
          youtube_url?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "events_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "events_event_type_id_fkey"
            columns: ["event_type_id"]
            isOneToOne: false
            referencedRelation: "event_types"
            referencedColumns: ["id"]
          },
        ]
      }
      group_join_codes: {
        Row: {
          code: string
          group_id: string
          updated_at: string
        }
        Insert: {
          code: string
          group_id: string
          updated_at?: string
        }
        Update: {
          code?: string
          group_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_join_codes_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: true
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
        ]
      }
      group_members: {
        Row: {
          apply_message: string | null
          approved_at: string | null
          created_at: string
          group_id: string
          role: Database["public"]["Enums"]["member_role"]
          status: Database["public"]["Enums"]["member_status"]
          user_id: string
        }
        Insert: {
          apply_message?: string | null
          approved_at?: string | null
          created_at?: string
          group_id: string
          role?: Database["public"]["Enums"]["member_role"]
          status?: Database["public"]["Enums"]["member_status"]
          user_id: string
        }
        Update: {
          apply_message?: string | null
          approved_at?: string | null
          created_at?: string
          group_id?: string
          role?: Database["public"]["Enums"]["member_role"]
          status?: Database["public"]["Enums"]["member_status"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_members_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      groups: {
        Row: {
          announcement: string | null
          created_at: string
          deleted_at: string | null
          description: string | null
          id: string
          name: string
          owner_id: string | null
        }
        Insert: {
          announcement?: string | null
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          id?: string
          name: string
          owner_id?: string | null
        }
        Update: {
          announcement?: string | null
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          id?: string
          name?: string
          owner_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "groups_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      live_streams: {
        Row: {
          ended_at: string | null
          id: string
          platform: string
          started_at: string
          title: string | null
          url: string
          video_id: string | null
        }
        Insert: {
          ended_at?: string | null
          id?: string
          platform: string
          started_at?: string
          title?: string | null
          url: string
          video_id?: string | null
        }
        Update: {
          ended_at?: string | null
          id?: string
          platform?: string
          started_at?: string
          title?: string | null
          url?: string
          video_id?: string | null
        }
        Relationships: []
      }
      media_items: {
        Row: {
          active: boolean
          category: string | null
          created_at: string
          id: string
          kind: Database["public"]["Enums"]["media_kind"]
          size_bytes: number | null
          sort_order: number
          source: Database["public"]["Enums"]["media_source"]
          title_hans: string
          title_hant: string
          url: string
        }
        Insert: {
          active?: boolean
          category?: string | null
          created_at?: string
          id?: string
          kind: Database["public"]["Enums"]["media_kind"]
          size_bytes?: number | null
          sort_order?: number
          source: Database["public"]["Enums"]["media_source"]
          title_hans: string
          title_hant: string
          url: string
        }
        Update: {
          active?: boolean
          category?: string | null
          created_at?: string
          id?: string
          kind?: Database["public"]["Enums"]["media_kind"]
          size_bytes?: number | null
          sort_order?: number
          source?: Database["public"]["Enums"]["media_source"]
          title_hans?: string
          title_hant?: string
          url?: string
        }
        Relationships: []
      }
      notification_reads: {
        Row: {
          notification_id: string
          read_at: string
          user_id: string
        }
        Insert: {
          notification_id: string
          read_at?: string
          user_id: string
        }
        Update: {
          notification_id?: string
          read_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_reads_notification_id_fkey"
            columns: ["notification_id"]
            isOneToOne: false
            referencedRelation: "notifications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_reads_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          body: string | null
          channels: string[]
          created_at: string
          event_id: string | null
          id: string
          payload: Json
          scheduled_at: string | null
          scope: Database["public"]["Enums"]["notification_scope"]
          sent_at: string | null
          target_id: string | null
          title: string
          type: string
        }
        Insert: {
          body?: string | null
          channels?: string[]
          created_at?: string
          event_id?: string | null
          id?: string
          payload?: Json
          scheduled_at?: string | null
          scope: Database["public"]["Enums"]["notification_scope"]
          sent_at?: string | null
          target_id?: string | null
          title?: string
          type?: string
        }
        Update: {
          body?: string | null
          channels?: string[]
          created_at?: string
          event_id?: string | null
          id?: string
          payload?: Json
          scheduled_at?: string | null
          scope?: Database["public"]["Enums"]["notification_scope"]
          sent_at?: string | null
          target_id?: string | null
          title?: string
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      practice_logs: {
        Row: {
          created_at: string
          deleted_at: string | null
          group_id: string
          id: string
          local_date: string
          note: string | null
          practice_type_id: string
          quantity: number
          reporter_id: string | null
          subject_name: string | null
          subject_user_id: string | null
          unit: Database["public"]["Enums"]["practice_unit"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          group_id: string
          id?: string
          local_date: string
          note?: string | null
          practice_type_id: string
          quantity: number
          reporter_id?: string | null
          subject_name?: string | null
          subject_user_id?: string | null
          unit: Database["public"]["Enums"]["practice_unit"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          group_id?: string
          id?: string
          local_date?: string
          note?: string | null
          practice_type_id?: string
          quantity?: number
          reporter_id?: string | null
          subject_name?: string | null
          subject_user_id?: string | null
          unit?: Database["public"]["Enums"]["practice_unit"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "practice_logs_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "practice_logs_practice_type_id_fkey"
            columns: ["practice_type_id"]
            isOneToOne: false
            referencedRelation: "practice_types"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "practice_logs_reporter_id_fkey"
            columns: ["reporter_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "practice_logs_subject_user_id_fkey"
            columns: ["subject_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      practice_types: {
        Row: {
          active: boolean
          category: Database["public"]["Enums"]["practice_category"]
          created_at: string
          group_id: string | null
          id: string
          is_custom: boolean
          name_hans: string
          name_hant: string
          sort_order: number
          unit: Database["public"]["Enums"]["practice_unit"]
        }
        Insert: {
          active?: boolean
          category?: Database["public"]["Enums"]["practice_category"]
          created_at?: string
          group_id?: string | null
          id?: string
          is_custom?: boolean
          name_hans: string
          name_hant: string
          sort_order?: number
          unit: Database["public"]["Enums"]["practice_unit"]
        }
        Update: {
          active?: boolean
          category?: Database["public"]["Enums"]["practice_category"]
          created_at?: string
          group_id?: string | null
          id?: string
          is_custom?: boolean
          name_hans?: string
          name_hant?: string
          sort_order?: number
          unit?: Database["public"]["Enums"]["practice_unit"]
        }
        Relationships: [
          {
            foreignKeyName: "practice_types_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          banned_at: string | null
          created_at: string
          display_name: string
          font_scale: number
          id: string
          is_app_admin: boolean
          locale: string
          recovery_email: string | null
          region: string
          timezone: string
        }
        Insert: {
          banned_at?: string | null
          created_at?: string
          display_name?: string
          font_scale?: number
          id: string
          is_app_admin?: boolean
          locale?: string
          recovery_email?: string | null
          region?: string
          timezone?: string
        }
        Update: {
          banned_at?: string | null
          created_at?: string
          display_name?: string
          font_scale?: number
          id?: string
          is_app_admin?: boolean
          locale?: string
          recovery_email?: string | null
          region?: string
          timezone?: string
        }
        Relationships: []
      }
      proxy_names: {
        Row: {
          created_by: string | null
          group_id: string
          id: string
          last_used_at: string
          name: string
          use_count: number
        }
        Insert: {
          created_by?: string | null
          group_id: string
          id?: string
          last_used_at?: string
          name: string
          use_count?: number
        }
        Update: {
          created_by?: string | null
          group_id?: string
          id?: string
          last_used_at?: string
          name?: string
          use_count?: number
        }
        Relationships: [
          {
            foreignKeyName: "proxy_names_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "proxy_names_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
        ]
      }
      push_tokens: {
        Row: {
          fcm_failed: boolean
          platform: Database["public"]["Enums"]["push_platform"]
          token: string
          updated_at: string
          user_id: string
        }
        Insert: {
          fcm_failed?: boolean
          platform: Database["public"]["Enums"]["push_platform"]
          token: string
          updated_at?: string
          user_id: string
        }
        Update: {
          fcm_failed?: boolean
          platform?: Database["public"]["Enums"]["push_platform"]
          token?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "push_tokens_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      reports: {
        Row: {
          created_at: string
          handled_by: string | null
          id: string
          reason: string
          reporter_id: string
          status: Database["public"]["Enums"]["report_status"]
          target_id: string
          target_type: Database["public"]["Enums"]["report_target"]
        }
        Insert: {
          created_at?: string
          handled_by?: string | null
          id?: string
          reason: string
          reporter_id: string
          status?: Database["public"]["Enums"]["report_status"]
          target_id: string
          target_type: Database["public"]["Enums"]["report_target"]
        }
        Update: {
          created_at?: string
          handled_by?: string | null
          id?: string
          reason?: string
          reporter_id?: string
          status?: Database["public"]["Enums"]["report_status"]
          target_id?: string
          target_type?: Database["public"]["Enums"]["report_target"]
        }
        Relationships: [
          {
            foreignKeyName: "reports_handled_by_fkey"
            columns: ["handled_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reports_reporter_id_fkey"
            columns: ["reporter_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      scriptures: {
        Row: {
          created_at: string
          id: string
          sort_order: number
          title: string
          web_url: string
        }
        Insert: {
          created_at?: string
          id?: string
          sort_order?: number
          title: string
          web_url: string
        }
        Update: {
          created_at?: string
          id?: string
          sort_order?: number
          title?: string
          web_url?: string
        }
        Relationships: []
      }
      user_blocks: {
        Row: {
          blocked_user_id: string
          created_at: string
          user_id: string
        }
        Insert: {
          blocked_user_id: string
          created_at?: string
          user_id: string
        }
        Update: {
          blocked_user_id?: string
          created_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_blocks_blocked_user_id_fkey"
            columns: ["blocked_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_blocks_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      vows: {
        Row: {
          created_at: string
          end_date: string
          group_id: string | null
          id: string
          practice_type_id: string
          start_date: string
          status: Database["public"]["Enums"]["vow_status"]
          target_qty: number
          user_id: string
        }
        Insert: {
          created_at?: string
          end_date: string
          group_id?: string | null
          id?: string
          practice_type_id: string
          start_date: string
          status?: Database["public"]["Enums"]["vow_status"]
          target_qty: number
          user_id: string
        }
        Update: {
          created_at?: string
          end_date?: string
          group_id?: string | null
          id?: string
          practice_type_id?: string
          start_date?: string
          status?: Database["public"]["Enums"]["vow_status"]
          target_qty?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "vows_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "vows_practice_type_id_fkey"
            columns: ["practice_type_id"]
            isOneToOne: false
            referencedRelation: "practice_types"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "vows_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      daily_group_stats: {
        Row: {
          entries: number | null
          group_id: string | null
          local_date: string | null
          practice_type_id: string | null
          total: number | null
          unit: Database["public"]["Enums"]["practice_unit"] | null
        }
        Relationships: [
          {
            foreignKeyName: "practice_logs_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "practice_logs_practice_type_id_fkey"
            columns: ["practice_type_id"]
            isOneToOne: false
            referencedRelation: "practice_types"
            referencedColumns: ["id"]
          },
        ]
      }
      daily_user_stats: {
        Row: {
          group_id: string | null
          local_date: string | null
          practice_type_id: string | null
          total: number | null
          unit: Database["public"]["Enums"]["practice_unit"] | null
          user_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "practice_logs_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "practice_logs_practice_type_id_fkey"
            columns: ["practice_type_id"]
            isOneToOne: false
            referencedRelation: "practice_types"
            referencedColumns: ["id"]
          },
        ]
      }
      group_member_display: {
        Row: {
          display_name: string | null
          group_id: string | null
          role: Database["public"]["Enums"]["member_role"] | null
          user_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "group_members_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      group_practice_totals: {
        Row: {
          entries: number | null
          group_id: string | null
          practice_type_id: string | null
          total: number | null
          unit: Database["public"]["Enums"]["practice_unit"] | null
        }
        Relationships: [
          {
            foreignKeyName: "practice_logs_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "practice_logs_practice_type_id_fkey"
            columns: ["practice_type_id"]
            isOneToOne: false
            referencedRelation: "practice_types"
            referencedColumns: ["id"]
          },
        ]
      }
      user_practice_totals: {
        Row: {
          entries: number | null
          practice_type_id: string | null
          total: number | null
          unit: Database["public"]["Enums"]["practice_unit"] | null
          user_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "practice_logs_practice_type_id_fkey"
            columns: ["practice_type_id"]
            isOneToOne: false
            referencedRelation: "practice_types"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      admin_cancel_notification: { Args: { p_id: string }; Returns: undefined }
      admin_list_logins: {
        Args: { p_user_ids: string[] }
        Returns: {
          login_email: string
          user_id: string
        }[]
      }
      admin_publish_notification: {
        Args: { p_body?: string; p_scheduled_at?: string; p_title: string }
        Returns: string
      }
      delete_practice_log: { Args: { p_log_id: string }; Returns: undefined }
      dissolve_group: { Args: { p_group_id: string }; Returns: undefined }
      gen_join_code: { Args: never; Returns: string }
      generate_almanac_notifications: { Args: never; Returns: undefined }
      get_group_join_code: { Args: { p_group_id: string }; Returns: string }
      has_group_relation: { Args: { gid: string }; Returns: boolean }
      invoke_push_dispatch: { Args: never; Returns: undefined }
      is_active_user: { Args: never; Returns: boolean }
      is_app_admin: { Args: never; Returns: boolean }
      is_group_member: { Args: { gid: string }; Returns: boolean }
      is_group_owner: { Args: { gid: string }; Returns: boolean }
      join_group: {
        Args: { p_code: string; p_message?: string }
        Returns: string
      }
      reset_group_join_code: { Args: { p_group_id: string }; Returns: string }
      transfer_group_ownership: {
        Args: { p_group_id: string; p_new_owner: string }
        Returns: undefined
      }
      vow_progress: { Args: { p_vow_id: string }; Returns: number }
    }
    Enums: {
      media_kind: "audio" | "video"
      media_source: "youtube" | "https"
      member_role: "owner" | "member"
      member_status: "pending" | "approved" | "rejected" | "removed" | "left"
      notification_scope: "user" | "group" | "all"
      practice_category:
        | "sutra"
        | "mantra"
        | "repentance"
        | "buddha_name"
        | "meditation"
        | "other"
      practice_unit: "volume" | "recitation" | "count" | "minute"
      push_platform: "apns" | "fcm"
      report_status: "open" | "resolved"
      report_target: "user" | "group" | "log"
      vow_status: "active" | "completed" | "expired" | "abandoned"
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
    Enums: {
      media_kind: ["audio", "video"],
      media_source: ["youtube", "https"],
      member_role: ["owner", "member"],
      member_status: ["pending", "approved", "rejected", "removed", "left"],
      notification_scope: ["user", "group", "all"],
      practice_category: [
        "sutra",
        "mantra",
        "repentance",
        "buddha_name",
        "meditation",
        "other",
      ],
      practice_unit: ["volume", "recitation", "count", "minute"],
      push_platform: ["apns", "fcm"],
      report_status: ["open", "resolved"],
      report_target: ["user", "group", "log"],
      vow_status: ["active", "completed", "expired", "abandoned"],
    },
  },
} as const

