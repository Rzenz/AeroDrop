import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface RequestPayload {
  order_id: string;
}

Deno.serve(async (req: Request) => {
  // Handle CORS pre-flight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const xenditSecretKey = Deno.env.get("XENDIT_SECRET_KEY") ?? "";

    if (!xenditSecretKey) {
      console.error("XENDIT_SECRET_KEY is missing from Supabase environment secrets");
      return new Response(JSON.stringify({ error: "Payment service is currently unavailable" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Authenticate caller JWT
    const supabaseUserClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: userError } = await supabaseUserClient.auth.getUser();

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Invalid or expired user session" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Parse request
    const body: RequestPayload = await req.json().catch(() => ({ order_id: "" }));
    const orderId = body.order_id?.trim();

    if (!orderId) {
      return new Response(JSON.stringify({ error: "order_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Query order using Service Role client to read database-authoritative total_amount
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    const { data: order, error: orderError } = await supabaseAdmin
      .from("orders")
      .select("id, user_id, order_status, payment_method, payment_status, total_amount, payment_invoice_id, payment_invoice_url")
      .eq("id", orderId)
      .maybeSingle();

    if (orderError || !order) {
      return new Response(JSON.stringify({ error: "Order not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify order ownership
    if (order.user_id !== user.id) {
      return new Response(JSON.stringify({ error: "Unauthorized: You do not own this order" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify payment method
    if (order.payment_method !== "xendit_online") {
      return new Response(JSON.stringify({ error: "Order payment method is not xendit_online" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Reject non-pending, already paid, or cancelled orders
    if (order.order_status !== "pending") {
      return new Response(JSON.stringify({ error: `Order cannot be paid in status: ${order.order_status}` }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (order.payment_status === "paid") {
      return new Response(JSON.stringify({ error: "Order has already been paid" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (order.payment_status !== "pending") {
      return new Response(JSON.stringify({ error: `Cannot process payment with status: ${order.payment_status}` }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Reuse existing valid invoice if already generated
    if (order.payment_invoice_url && order.payment_invoice_id) {
      return new Response(
        JSON.stringify({
          success: true,
          reused: true,
          order_id: order.id,
          invoice_id: order.payment_invoice_id,
          invoice_url: order.payment_invoice_url,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Create Xendit Invoice (amount read strictly from database)
    const rawTotalAmount = Number(order.total_amount);
    if (isNaN(rawTotalAmount) || rawTotalAmount <= 0) {
      return new Response(JSON.stringify({ error: "Invalid order amount" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Preserve exact total_amount with 2 decimal places precision as a number (PHP centavos)
    const amountNumber = Math.round(rawTotalAmount * 100) / 100;

    // Safety check: refuse to create invoice if amount differs from orders.total_amount
    // (guards against any unexpected rounding, tampering, or precision discrepancies)
    if (Math.abs(amountNumber - rawTotalAmount) > 0.0001) {
      console.error(
        `Safety check failed: order.total_amount (${rawTotalAmount}) differs from invoice amount (${amountNumber})`
      );
      return new Response(
        JSON.stringify({ error: "Order amount mismatch. Please refresh and try again." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const shortId = order.id.slice(0, 8);
    const basicAuth = btoa(`${xenditSecretKey}:`);

    // Note: payment_methods is intentionally omitted so Xendit automatically displays
    // all enabled payment channels for the account (GCash, Card, etc.) without rejection.
    const xenditPayload: Record<string, unknown> = {
      external_id: order.id,
      amount: amountNumber,
      description: `AeroDrop Delivery #${shortId}`,
      currency: "PHP",
      invoice_duration: 900, // 15 minutes expiry
      customer: {
        email: user.email ?? undefined,
      },
      customer_notification_preference: {
        invoice_created: [],
        invoice_reminder: [],
        invoice_paid: [],
        invoice_expired: [],
      },
    };

    const xenditResponse = await fetch("https://api.xendit.co/v2/invoices", {
      method: "POST",
      headers: {
        "Authorization": `Basic ${basicAuth}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(xenditPayload),
    });

    if (!xenditResponse.ok) {
      const errorText = await xenditResponse.text();
      // Server-side logging only; never leak gateway internals or auth headers to client
      console.error(`Xendit create invoice error (HTTP ${xenditResponse.status}):`, errorText);
      return new Response(
        JSON.stringify({ error: "Could not start payment. Please try again." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const invoiceData = await xenditResponse.json();

    // 5. Store invoice details on order
    const { error: updateError } = await supabaseAdmin
      .from("orders")
      .update({
        payment_invoice_id: invoiceData.id,
        payment_invoice_url: invoiceData.invoice_url,
        payment_provider: "xendit",
        updated_at: new Date().toISOString(),
      })
      .eq("id", order.id);

    if (updateError) {
      console.error("Failed to attach invoice to order:", updateError.message);
      return new Response(
        JSON.stringify({ error: "Could not start payment. Please try again." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        order_id: order.id,
        invoice_id: invoiceData.id,
        invoice_url: invoiceData.invoice_url,
        expiry_date: invoiceData.expiry_date,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: unknown) {
    console.error("Unhandled error in create-xendit-payment:", err);
    return new Response(JSON.stringify({ error: "Could not start payment. Please try again." }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
