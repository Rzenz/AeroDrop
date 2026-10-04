import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

interface XenditInvoiceWebhookPayload {
  id: string;
  external_id: string;
  user_id?: string;
  status: "PAID" | "EXPIRED" | "FAILED";
  merchant_name?: string;
  amount: number;
  paid_amount?: number;
  payment_method?: string;
  payment_channel?: string;
  payment_destination?: string;
  paid_at?: string;
  created?: string;
  updated?: string;
  currency?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    // 1. Verify Xendit Callback Verification Token
    const callbackToken = req.headers.get("x-callback-token");
    const expectedToken = Deno.env.get("XENDIT_CALLBACK_TOKEN");

    if (!expectedToken || !callbackToken || callbackToken !== expectedToken) {
      console.warn("Rejected webhook request: Invalid or missing x-callback-token");
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const payload: XenditInvoiceWebhookPayload = await req.json();
    const orderId = payload.external_id?.trim();
    const invoiceId = payload.id;
    const invoiceStatus = payload.status?.toUpperCase();

    if (!orderId || !invoiceStatus) {
      return new Response(JSON.stringify({ error: "Missing required webhook parameters" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 2. Validate external_id is a UUID (Xendit test pings send strings like "invoice_123124123")
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(orderId);
    if (!isUuid) {
      console.log(`Xendit webhook received non-UUID external_id: "${orderId}". Ignoring.`);
      return new Response(JSON.stringify({ received: true, ignored: "not a UUID" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    // 3. Verify order exists
    const { data: existingOrder, error: fetchError } = await supabaseAdmin
      .from("orders")
      .select("id, payment_status, order_status, vendor_id, user_id, total_amount")
      .eq("id", orderId)
      .maybeSingle();

    if (fetchError) {
      console.error("Database error looking up order:", fetchError.message);
      return new Response(JSON.stringify({ error: "Database lookup error" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (!existingOrder) {
      console.log(`Xendit webhook received valid UUID external_id "${orderId}" but order was not found. Ignoring.`);
      return new Response(JSON.stringify({ received: true, ignored: "order not found" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 4. Handle PAID Invoices (Idempotent update)
    if (invoiceStatus === "PAID") {
      if (existingOrder.payment_status === "paid") {
        return new Response(JSON.stringify({ received: true, status: "already_paid" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }

      const channel = payload.payment_channel || payload.payment_method || "ONLINE";
      const paidAt = payload.paid_at ? new Date(payload.paid_at).toISOString() : new Date().toISOString();

      // Atomic update guarded by payment_status != 'paid'
      const { data: updatedOrders, error: updateError } = await supabaseAdmin
        .from("orders")
        .update({
          payment_status: "paid",
          payment_channel: channel,
          payment_reference: invoiceId,
          paid_at: paidAt,
          updated_at: new Date().toISOString(),
        })
        .eq("id", orderId)
        .neq("payment_status", "paid")
        .select("id, user_id, vendor_id, total_amount");

      if (updateError) {
        console.error("Failed to update order payment status to paid:", updateError.message);
        return new Response(JSON.stringify({ error: "Database update error" }), {
          status: 500,
          headers: { "Content-Type": "application/json" },
        });
      }

      // Exactly one process will transition payment_status from pending to paid
      if (updatedOrders && updatedOrders.length > 0) {
        const order = updatedOrders[0];

        // Notify Vendor: Order is paid and now visible/actionable
        await supabaseAdmin.from("notifications").insert({
          id: crypto.randomUUID(),
          user_id: order.vendor_id,
          title: "New Customer Order!",
          message: `You have received a new paid order for ₱${Number(order.total_amount).toFixed(2)}.`,
          notification_type: "new_order",
          is_read: false,
          created_at: new Date().toISOString(),
        });

        // Notify Customer: Payment verified
        await supabaseAdmin.from("notifications").insert({
          id: crypto.randomUUID(),
          user_id: order.user_id,
          title: "Payment Confirmed",
          message: `Your payment via ${channel} has been verified. The vendor will begin preparation soon.`,
          notification_type: "order_confirmed",
          is_read: false,
          created_at: new Date().toISOString(),
        });
      }

      return new Response(JSON.stringify({ received: true, status: "paid_processed" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 5. Handle EXPIRED / FAILED Invoices
    if (invoiceStatus === "EXPIRED" || invoiceStatus === "FAILED") {
      const newPaymentStatus = invoiceStatus === "EXPIRED" ? "expired" : "failed";

      // If order is still pending, cancel it and release inventory
      const { data: cancelledOrders } = await supabaseAdmin
        .from("orders")
        .update({
          order_status: "cancelled",
          payment_status: newPaymentStatus,
          cancellation_reason: "payment_expired",
          updated_at: new Date().toISOString(),
        })
        .eq("id", orderId)
        .eq("order_status", "pending")
        .eq("payment_status", "pending")
        .select("id, user_id");

      // Cancellation automatically triggers trg_order_cancellation_after to restore stock
      return new Response(
        JSON.stringify({
          received: true,
          status: `${newPaymentStatus}_processed`,
          cancelled: (cancelledOrders?.length ?? 0) > 0,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify({ received: true, ignored: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err: unknown) {
    console.error("Unhandled error in xendit-webhook:", err);
    return new Response(JSON.stringify({ error: "Webhook processing error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
