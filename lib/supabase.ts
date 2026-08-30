import { createClient } from "@supabase/supabase-js";

export function supabaseBrowser() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  );
}

export function syntheticEmail(phone: string) {
  return `${phone.replace(/\D/g, "")}@hamli.local`;
}
