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
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      colaboradores: {
        Row: {
          colaborador_id: string | null
          competencia: string | null
          id: string
          nome_colaborador: string | null
          origem: string | null
          posicao: string | null
          squad: string | null
          meta_alcancada: string | null
          senioridade: string | null
          senioridade_informada: string | null
          recebeu_promocao: boolean
          mes_referencia: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          colaborador_id?: string | null
          competencia?: string | null
          id?: string
          nome_colaborador?: string | null
          origem?: string | null
          posicao?: string | null
          squad?: string | null
          meta_alcancada?: string | null
          senioridade?: string | null
          senioridade_informada?: string | null
          recebeu_promocao?: boolean
          mes_referencia?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          colaborador_id?: string | null
          competencia?: string | null
          id?: string
          nome_colaborador?: string | null
          origem?: string | null
          posicao?: string | null
          squad?: string | null
          meta_alcancada?: string | null
          senioridade?: string | null
          senioridade_informada?: string | null
          recebeu_promocao?: boolean
          mes_referencia?: string | null
          created_at?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "colaboradores_colaborador_id_fkey"
            columns: ["colaborador_id"]
            isOneToOne: false
            referencedRelation: "colaboradores_perfis"
            referencedColumns: ["id"]
          },
        ]
      }
      colaboradores_perfis: {
        Row: {
          created_at: string
          id: string
          jornada_atual: string | null
          nome_colaborador: string
          nome_normalizado: string
          posicao_atual: string | null
          progresso_meta3: number
          senioridade_atual: string | null
          squad_atual: string | null
          ativo: boolean
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          jornada_atual?: string | null
          nome_colaborador: string
          nome_normalizado: string
          posicao_atual?: string | null
          progresso_meta3?: number
          senioridade_atual?: string | null
          squad_atual?: string | null
          ativo?: boolean
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          jornada_atual?: string | null
          nome_colaborador?: string
          nome_normalizado?: string
          posicao_atual?: string | null
          progresso_meta3?: number
          senioridade_atual?: string | null
          squad_atual?: string | null
          ativo?: boolean
          updated_at?: string
        }
        Relationships: []
      }
      career_migration_issues: {
        Row: {
          created_at: string
          colaboradores_id: string | null
          details: string
          id: number
          issue_type: string
          raw_value: string | null
        }
        Insert: {
          created_at?: string
          colaboradores_id?: string | null
          details: string
          id?: number
          issue_type: string
          raw_value?: string | null
        }
        Update: {
          created_at?: string
          colaboradores_id?: string | null
          details?: string
          id?: number
          issue_type?: string
          raw_value?: string | null
        }
        Relationships: []
      }
      sdrs: {
        Row: {
          avatar_color: string
          created_at: string
          history: Json
          id: string
          level: string
          meta3_progress: number
          name: string
          sort_order: number
          squad: string
          updated_at: string
        }
        Insert: {
          avatar_color?: string
          created_at?: string
          history?: Json
          id: string
          level: string
          meta3_progress?: number
          name: string
          sort_order?: number
          squad: string
          updated_at?: string
        }
        Update: {
          avatar_color?: string
          created_at?: string
          history?: Json
          id?: string
          level?: string
          meta3_progress?: number
          name?: string
          sort_order?: number
          squad?: string
          updated_at?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      registrar_resultado_mensal: {
        Args: {
          p_colaborador_id: string
          p_competencia: string
          p_meta: string
        }
        Returns: Database["public"]["Tables"]["colaboradores"]["Row"]
      }
      recalcular_progressao_colaborador: {
        Args: { p_colaborador_id: string }
        Returns: undefined
      }
      sincronizar_progressao_planilha: {
        Args: {
          p_origem: string
          p_perfis: Json
          p_resultados: Json
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
  public: {
    Enums: {},
  },
} as const
