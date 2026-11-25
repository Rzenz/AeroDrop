import { Download } from 'lucide-react'
import { useState } from 'react'
import { api } from '@/data/api'
import { errorMessage } from '@/lib/store'
import { Button } from './ui/button'
import { toast } from './ui/toast'

/** The file order_to_mission.py reads: order-<first 8 of the id>.json. */
const flightPlanFileName = (orderId: string) => `order-${orderId.slice(0, 8)}.json`

/**
 * ADMIN ONLY: render this only on admin screens. Fetches the order's flight
 * plan (get_order_flight_plan) and saves it as JSON, the input to
 * order_to_mission.py. While the fetch runs only this button is disabled; an
 * error shows beside it in the server's own words.
 */
export function FlightPlanButton({ orderId, size = 'md' }: { orderId: string; size?: 'sm' | 'md' }) {
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function download() {
    setBusy(true)
    setError(null)
    try {
      // The plan's pickup and drop-off are only final once the vendor has
      // marked the order ready; before that they fall back to the vendor's
      // building and the order's drop-off. The JSON carries delivery.status,
      // so the operator can tell which they have.
      const plan = await api.orderFlightPlan(orderId)
      // Saved as the server returned it: re-serialised with a 2-space indent,
      // keys in the order they arrived, nothing rounded or dropped.
      const blob = new Blob([`${JSON.stringify(plan, null, 2)}\n`], { type: 'application/json' })
      const url = URL.createObjectURL(blob)
      const name = flightPlanFileName(orderId)
      const a = document.createElement('a')
      a.href = url
      a.download = name
      document.body.appendChild(a)
      a.click()
      a.remove()
      // After the click has started the download
      setTimeout(() => URL.revokeObjectURL(url), 0)
      toast(`Flight plan saved: ${name}`)
    } catch (e) {
      // The server's sentence, e.g. 'Unauthorized: caller cannot read this order'
      setError(errorMessage(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <span className="inline-flex flex-col items-start gap-1">
      <Button variant="secondary" size={size} loading={busy} icon={<Download aria-hidden className="size-4" />} onClick={download}>
        Download flight plan
      </Button>
      {error ? (
        <span role="alert" className="max-w-64 text-xs font-medium text-danger">
          {error}
        </span>
      ) : null}
    </span>
  )
}
