import L from 'leaflet'
import { Building2, Check, CircleAlert, MapPin } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { Circle, MapContainer, Marker, TileLayer, useMap, useMapEvents } from 'react-leaflet'
import type { DeliveryZone } from '@/data/api'
import { isTestPoint, pin as campusPin } from '@/lib/campus-markers'
import { isHub } from '@/lib/flight'
import { distanceMeters } from '@/lib/flight-calc'
import { cn } from '@/lib/utils'
import type { CampusLocation } from '@/types'
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

/**
 * What the picker returns (DropoffPick in the app): a campus location when one
 * of its markers was clicked, or a pin when open ground was. A building goes on
 * the order as delivery_location_id, never as coordinates, so the order keeps
 * its link to the building and the vendor sees its name.
 */
export type DropoffPick = { kind: 'location'; location: CampusLocation } | { kind: 'pin'; pin: PinnedDropoff }

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
 * Every campus location is drawn with the live map's markers. Clicking a
 * building selects it as a fixed drop-off; clicking open ground places or
 * moves a pin. The hub is shown greyed and ignores clicks. The circle and the
 * distance are a guide for the customer; the server decides whether a pin is
 * allowed when the order is quoted and placed.
 */
export function DropoffMapPicker({
  zone,
  initial,
  locations = [],
  onConfirm,
  onCancel,
}: {
  zone: DeliveryZone
  initial: PinnedDropoff | null
  /** The campus_locations rows, hub included. */
  locations?: CampusLocation[]
  onConfirm: (pick: DropoffPick) => void
  onCancel: () => void
}) {
  const [pin, setPin] = useState<[number, number] | null>(initial ? [initial.lat, initial.lng] : null)
  const [label, setLabel] = useState(initial?.label ?? '')
  // A building chosen by clicking its marker. Exclusive with the pin.
  const [location, setLocation] = useState<CampusLocation | null>(null)
  const placePin = (p: [number, number]) => {
    setPin(p)
    setLocation(null)
  }

  const center = useMemo<[number, number]>(() => [zone.centerLatitude, zone.centerLongitude], [zone.centerLatitude, zone.centerLongitude])
  // The circle's box with a margin for the first view; a wider one keeps the map on campus.
  const fit = useMemo(() => L.latLng(center).toBounds(zone.radiusMeters * 2 * 1.15), [center, zone.radiusMeters])
  const limit = useMemo(() => L.latLng(center).toBounds(zone.radiusMeters * 2 * 2.5), [center, zone.radiusMeters])

  const meters = pin ? distanceMeters(center, pin) : null
  const outside = meters != null && meters > zone.radiusMeters
  const readout = location
    ? `${location.name}: a campus drop-off point.`
    : meters == null
      ? 'Click a building to choose it, or click open ground inside the circle to place a pin.'
      : outside
        ? `Outside the delivery area: ${Math.round(meters)} m from ${zone.centerName}, and the limit is ${Math.round(zone.radiusMeters)} m.`
        : `${Math.round(meters)} m from ${zone.centerName}. Inside the delivery area.`

  return (
    <Dialog open onOpenChange={(v) => !v && onCancel()} title="Pin your drop-off" description="Click a building to choose it, or open ground to place a pin." className="max-w-2xl">
      <div className="relative isolate h-80 overflow-hidden rounded-xl bg-sunken sm:h-96">
        <MapContainer bounds={fit} boundsOptions={{ padding: [24, 24] }} minZoom={15} maxZoom={20} maxBounds={limit} maxBoundsViscosity={1} className="size-full cursor-crosshair" attributionControl>
          <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={20} maxNativeZoom={19} />
          <SettleSize bounds={fit} />
          <ClickToPlace onPick={placePin} />
          <Circle center={center} radius={zone.radiusMeters} pathOptions={{ color: '#3A6FD4', weight: 2, fillOpacity: 0.12 }} interactive={false} />
          {locations.map((l) =>
            isHub(l) ? (
              // Shown greyed, and its clicks are swallowed so they never drop a
              // pin: Leaflet only stops a click at a marker that listens for
              // it, hence the empty handler. Painted under the buildings: it
              // sits 26 m from Maritime, and on top it would take their clicks.
              <Marker key={l.id} position={[l.latitude, l.longitude]} icon={campusPin('hub')} opacity={0.4} zIndexOffset={-1000} keyboard={false} title={`${l.name} (the drone hub, not a drop-off point)`} bubblingMouseEvents={false} eventHandlers={{ click: () => {} }} />
            ) : (
              <Marker
                key={l.id}
                position={[l.latitude, l.longitude]}
                icon={campusPin(location?.id === l.id ? 'drop' : 'stop', isTestPoint(l))}
                title={l.name}
                bubblingMouseEvents={false}
                eventHandlers={{
                  click: () => {
                    setLocation(l)
                    setPin(null)
                  },
                }}
              />
            ),
          )}
          {/* Not interactive, so a click on the pin still reaches the map and moves it */}
          {pin ? <Marker position={pin} icon={pinIcon(outside)} interactive={false} keyboard={false} zIndexOffset={1000} /> : null}
        </MapContainer>
      </div>

      <p role="status" aria-live="polite" className={cn('mt-4 flex items-start gap-2 text-sm', outside ? 'font-semibold text-danger' : 'font-medium text-ink')}>
        {outside ? <CircleAlert aria-hidden className="mt-0.5 size-4 shrink-0" /> : location ? <Building2 aria-hidden className="mt-0.5 size-4 shrink-0 text-brand" /> : <MapPin aria-hidden className="mt-0.5 size-4 shrink-0 text-ink-3" />}
        <span>{readout}</span>
      </p>

      {/* A building already has a name; only a pin is described */}
      {location ? null : (
        <Field label="Describe the spot (optional)" hint={`${label.length}/${DROPOFF_LABEL_MAX}`} className="mt-4">
          {(p) => <Input {...p} value={label} maxLength={DROPOFF_LABEL_MAX} placeholder="e.g. by the side gate" onChange={(e) => setLabel(e.target.value)} />}
        </Field>
      )}

      <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button type="button" variant="secondary" onClick={onCancel}>
          Cancel
        </Button>
        <Button
          type="button"
          icon={<Check aria-hidden className="size-4" />}
          disabled={!location && (!pin || outside)}
          onClick={() => {
            if (location) onConfirm({ kind: 'location', location })
            else if (pin) onConfirm({ kind: 'pin', pin: { lat: pin[0], lng: pin[1], label: label.trim() || null } })
          }}
        >
          Confirm drop-off
        </Button>
      </div>
    </Dialog>
  )
}
