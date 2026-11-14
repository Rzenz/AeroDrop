// check-email: can this address really receive mail?
//
// Called by the app (AuthNotifier.register) and the website (sign-up) before
// an account is created. Signed-out callers use it, so it must be deployed
// with --no-verify-jwt:
//
//   supabase functions deploy check-email --no-verify-jwt
//
// It always answers 200 with { ok, reason?, message?, suggestion? } so clients
// can show the message. When the DNS lookup itself fails it answers ok with
// `unchecked: true`: the emailed sign-up code still proves the inbox, and a
// DNS outage must never stop real people from registering.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Result = {
  ok: boolean;
  reason?: "invalid" | "disposable" | "typo" | "no_domain" | "no_mail";
  message?: string;
  suggestion?: string;
  unchecked?: boolean;
};

const reply = (body: Result) =>
  new Response(JSON.stringify(body), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

// RFC 5322 "dot-atom" local part and an LDH domain with at least one dot.
const EMAIL_RE =
  /^[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/;

interface DnsAnswer {
  type: number;
  data: string;
}
interface DnsReply {
  Status: number;
  Answer?: DnsAnswer[];
}

async function resolve(name: string, type: "MX" | "A" | "AAAA"): Promise<DnsReply> {
  const res = await fetch(
    `https://dns.google/resolve?name=${encodeURIComponent(name)}&type=${type}`,
    { headers: { accept: "application/dns-json" }, signal: AbortSignal.timeout(4000) },
  );
  if (!res.ok) throw new Error(`DNS lookup failed (${res.status})`);
  return await res.json();
}

const NXDOMAIN = 3;
const NOERROR = 0;

async function blockedDomain(email: string) {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return null;
  try {
    const sb = createClient(url, key, { auth: { persistSession: false } });
    const { data, error } = await sb.rpc("blocked_email_domain", { p_email: email });
    if (error) {
      console.error("blocked_email_domain failed:", error.message);
      return null;
    }
    const row = Array.isArray(data) ? data[0] : data;
    return row?.domain ? (row as { domain: string; reason: "disposable" | "typo"; suggestion: string | null }) : null;
  } catch (e) {
    console.error("blocked_email_domain threw:", e);
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let email = "";
  try {
    const body = await req.json();
    email = String(body?.email ?? "").trim().toLowerCase();
  } catch {
    // Falls through to the invalid answer.
  }

  const [local = "", domain = ""] = email.split("@");
  if (!email || email.length > 254 || local.length > 64 || !EMAIL_RE.test(email)) {
    return reply({ ok: false, reason: "invalid", message: "Enter a valid email address." });
  }

  const blocked = await blockedDomain(email);
  if (blocked?.reason === "typo" && blocked.suggestion) {
    const suggestion = `${local}@${blocked.suggestion}`;
    return reply({ ok: false, reason: "typo", suggestion, message: `Did you mean ${suggestion}?` });
  }
  if (blocked) {
    return reply({
      ok: false,
      reason: "disposable",
      message: "Temporary email addresses can't be used. Use your personal or school email.",
    });
  }

  try {
    const mx = await resolve(domain, "MX");
    if (mx.Status === NXDOMAIN) {
      return reply({ ok: false, reason: "no_domain", message: `${domain} doesn't exist. Check the spelling of your email.` });
    }
    if (mx.Status !== NOERROR) return reply({ ok: true, unchecked: true });

    const records = (mx.Answer ?? []).filter((a) => a.type === 15);
    if (records.length) {
      // RFC 7505 "null MX" (0 .): the domain says it accepts no mail.
      const nullMx = records.every((r) => /^0\s+\.?$/.test(r.data.trim()));
      return nullMx
        ? reply({ ok: false, reason: "no_mail", message: `${domain} doesn't accept email. Use a different address.` })
        : reply({ ok: true });
    }

    // No MX: mail falls back to the domain's own address (RFC 5321 §5.1).
    for (const type of ["A", "AAAA"] as const) {
      const addr = await resolve(domain, type);
      if (addr.Status === NOERROR && (addr.Answer ?? []).some((a) => a.type === 1 || a.type === 28)) {
        return reply({ ok: true });
      }
    }
    return reply({ ok: false, reason: "no_mail", message: `${domain} can't receive email. Check the spelling of your email.` });
  } catch (e) {
    console.error("check-email DNS lookup failed:", e);
    return reply({ ok: true, unchecked: true });
  }
});
