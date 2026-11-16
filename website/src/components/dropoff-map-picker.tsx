import L from 'leaflet'
import { Check, CircleAlert, MapPin } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { Circle, MapContainer, Marker, TileLayer, useMap, useMapEvents } from 'react-leaflet'
import type { DeliveryZone } from '@/data/api'
import { distanceMeters } from '@/lib/flight-calc'
import { cn } from '@/lib/utils'
import { Button } from './ui/button'
import { Dialog } from './ui/dialog'
import { Field, Input } from './ui/primitives'

/** A drop-off point the customer placed on the map. */
export interface PinnedDropoff {
  lat: number
  lng: number
  label: string | null
}

/** Longest description the customer may give the spot (kDropoffLabelMaxLength). */
export const DROPOFF_LABEL_MAX = 80

// Same family as campus-map.tsx's pins; the tip sits on the chosen point.
const pinIcon = (outside: boolean) =>
  L.divIcon({
    className: '',
    iconSize: [36, 36],
    iconAnchor: [18, 34],
    html: `<svg width="36" height="36" viewBox="0 0 24 24" style="filter:drop-shadow(0 2px 4px rgba(0,0,0,.45))"><path d="M12 22s7-6.2 7-12a7 7 0 1 0-14 0c0 5.8 7 12 7 12Z" fill="${outside ? '#EF5C74' : '#2BBE8A'}" stroke="#fff" stroke-width="1.6"/><circle cx="12" cy="10" r="2.6" fill="#fff"/></svg>`,
  })

/**
 * The map can initialise while the dialog's container still has no size, which
 * leaves grey tiles and the wrong zoom. Watch the container: whenever it has a
 * real size, let Leaflet measure again, and fit the zone circle the first time
 * so a later resize doesn't throw away the customer's pan and zoom.
 */
function SettleSize({ bounds }: { bounds: L.LatLngBounds }) {
  const map = useMap()
  useEffect(() => {
    const el = map.getContainer()
    let fitted = false
    const settle = () => {
      if (!el.clientWidth || !el.clientHeight) return
      map.invalidateSize()
      if (!fitted) {
        fitted = true
        map.fitBounds(bounds, { padding: [24, 24] })
      }
    }
    const ro = new ResizeObserver(settle)
    ro.observe(el)
    settle()
    return () => ro.disconnect()
  }, [map, bounds])
  return null
}

function ClickToPlace({ onPick }: { onPick: (p: [number, number]) => void }) {
  useMapEvents({ click: (e) => onPick([e.latlng.lat, e.latlng.lng]) })
  return null
}

/**
 * dropoff_map_picker.dart: choose a drop-off inside the delivery zone.
 * One interaction: click the map to place or move the pin. The circle and the
 * distance are a guide for the customer; the server decides whether the point
 * is allowed when the order is quoted and placed.
 */
export function DropoffMapPicker({ zone, initial, onConfirm, onCancel }: { zone: DeliveryZone; initial: PinnedDropoff | null; onConfirm: (pin: PinnedDropoff) => void; onCancel: () => void }) {
  const [pin, setPin] = useState<[number, number] | null>(initial ? [initial.lat, initial.lng] : null)
  const [label, setLabel] = useState(initial?.label ?? '')

  const center = useMemo<[number, number]>(() => [zone.centerLatitude, zone.centerLongitude], [zone.centerLatitude, zone.centerLongitude])
  // The circle's box with a margin for the first view; a wider one keeps the map on campus.
  const fit = useMemo(() => L.latLng(center).toBounds(zone.radiusMeters * 2 * 1.15), [center, zone.radiusMeters])
  const limit = useMemo(() => L.latLng(center).toBounds(zone.radiusMeters * 2 * 2.5), [center, zone.radiusMeters])

  const meters = pin ? distanceMeters(center, pin) : null
  const outside = meters != null && meters > zone.radiusMeters
  const readout =
    meters == null
      ? 'Click the map to place your pin inside the circle.'
      : outside
        ? `Outside the delivery area: ${Math.round(meters)} m from ${zone.centerName}, and the limit is ${Math.round(zone.radiusMeters)} m.`
        : `${Math.round(meters)} m from ${zone.centerName}. Inside the delivery area.`

  return (
    <Dialog open onOpenChange={(v) => !v && onCancel()} title="Pin your drop-off" description="Click the map to place or move your pin." className="max-w-2xl">
      <div className="relative isolate h-80 overflow-hidden rounded-xl bg-sunken sm:h-96">
        <MapContainer bounds={fit} boundsOptions={{ padding: [24, 24] }} minZoom={15} maxZoom={20} maxBounds={limit} maxBoundsViscosity={1} className="size-full cursor-crosshair" attributionControl>
          <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={20} maxNativeZoom={19} />
          <SettleSize bounds={fit} />
          <ClickToPlace onPick={setPin} />
          <Circle center={center} radius={zone.radiusMeters} pathOptions={{ color: '#3A6FD4', weight: 2, fillOpacity: 0.12 }} interactive={false} />
          {/* Not interactive, so a click on the pin still reaches the map and moves it */}
          {pin ? <Marker position={pin} icon={pinIcon(outside)} interactive={false} keyboard={false} /> : null}
        </MapContainer>
      </div>

      <p role="status" aria-live="polite" className={cn('mt-4 flex items-start gap-2 text-sm', outside ? 'font-semibold text-danger' : 'font-medium text-ink')}>
        {outside ? <CircleAlert aria-hidden className="mt-0.5 size-4 shrink-0" /> : <MapPin aria-hidden className="mt-0.5 size-4 shrink-0 text-ink-3" />}
        <span>{readout}</span>
      </p>

      <Field label="Describe the spot (optional)" hint={`${label.length}/${DROPOFF_LABEL_MAX}`} className="mt-4">
        {(p) => <Input {...p} value={label} maxLength={DROPOFF_LABEL_MAX} placeholder="e.g. by the side gate" onChange={(e) => setLabel(e.target.value)} />}
      </Field>

      <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button type="button" variant="secondary" onClick={onCancel}>
          Cancel
        </Button>
        <Button
          type="button"
          icon={<Check aria-hidden className="size-4" />}
          disabled={!pin || outside}
          onClick={() => pin && onConfirm({ lat: pin[0], lng: pin[1], label: label.trim() || null })}
        >
          Confirm drop-off
        </Button>
      </div>
    </Dialog>
  )
}
