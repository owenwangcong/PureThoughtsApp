import { createClient } from "@supabase/supabase-js";
import type { Database } from "./database.types";

// 默认指向 Supabase CLI 本地栈(与 app/ 的默认一致);
// 生产构建通过 .env.production.local 覆盖(见 README)。
const LOCAL_URL = "http://127.0.0.1:54321";
const LOCAL_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";

export const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? LOCAL_URL;

export const supabase = createClient<Database>(
  supabaseUrl,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? LOCAL_ANON_KEY,
);
