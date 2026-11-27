import type { Api } from '@/data/api'

/**
 * The vendor's "Ready for drone pickup" action: vendor_mark_order_ready
 * assigns DRN-001 and leaves the delivery in 'assigning'. Nothing flies until
 * the operator sends the delivery to the drone from the admin app; the
 * ground-station bridge (python_script/aio.py) then writes the real telemetry
 * and moves the delivery on.
 */
export async function markOrderReadyAndDispatch(api: Api, orderId: string): Promise<string> {
  return api.markOrderReady(orderId)
}
