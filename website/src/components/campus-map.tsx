import L from 'leaflet'
import { useEffect, useMemo } from 'react'
import { Circle, MapContainer, Marker, Polyline, TileLayer, Tooltip, useMap, useMapEvents } from 'react-leaflet'
import { isHub } from '@/lib/flight'
import { cn } from '@/lib/utils'
import type { CampusLocation, NoFlyZone } from '@/types'

export interface MapDrone {
  id: string
  label: string
  latitude: number
  longitude: number
  active?: boolean
}

const pin = (kind: 'hub' | 'stop' | 'drop' | 'vendor') =>
  L.divIcon({
    className: '',
    iconSize: [28, 28],
    iconAnchor: [14, 14],
    html: `<span style="display:grid;place-items:center;width:28px;height:28px;border-radius:999px;background:${
      kind === 'hub' ? '#19223B' : kind === 'drop' ? '#3A6FD4' : kind === 'vendor' ? '#2BBE8A' : '#ffffff'
    };box-shadow:0 0 0 2px ${kind === 'stop' ? '#3A6FD4' : '#ffffff'},0 4px 10px rgba(0,0,0,.25);color:${kind === 'stop' ? '#3A6FD4' : '#fff'};font:700 11px Inter,sans-serif">${
      kind === 'hub' ? 'H' : kind === 'drop' ? '▼' : kind === 'vendor' ? '◆' : '•'
    }</span>`,
  })

const droneIcon = (active: boolean) =>
  L.divIcon({
    className: '',
    iconSize: [40, 40],
    iconAnchor: [20, 20],
    html: `<span style="position:relative;display:grid;place-items:center;width:40px;height:40px">
      ${active ? '<span class="drone-ping" style="position:absolute;inset:0;border-radius:999px;background:rgba(79,177,246,.35)"></span>' : ''}
      <span style="position:relative;display:grid;place-items:center;width:30px;height:30px;border-radius:999px;background:linear-gradient(#4FB1F6,#3A6FD4);box-shadow:0 0 0 2px #fff,0 6px 14px rgba(58,111,212,.5)">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round"><path d="M12 12h.01M5 5l4 4m10-4-4 4m-6 6-4 4m14 0-4-4"/><circle cx="5" cy="5" r="2"/><circle cx="19" cy="5" r="2"/><circle cx="5" cy="19" r="2"/><circle cx="19" cy="19" r="2"/></svg>
      </span></span>`,
  })

function FitTo({ points }: { points: [number, number][] }) {
  const map = useMap()
  const key = points.map((p) => p.join(',')).join('|')
  useEffect(() => {
    if (points.length > 1) map.fitBounds(L.latLngBounds(points), { padding: [36, 36], maxZoom: 19 })
    // Only refit when the set of points changes, not on every drone tick.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, map])
  return null
}

function ClickCapture({ onPick }: { onPick: (lat: number, lng: number) => void }) {
  useMapEvents({ click: (e) => onPick(e.latlng.lat, e.latlng.lng) })
  return null
}

export function CampusMap({
  locations,
  drones = [],
  zones = [],
  route,
  highlight,
  onPick,
  className,
  label,
}: {
  locations: CampusLocation[]
  drones?: MapDrone[]
  zones?: NoFlyZone[]
  route?: { from: CampusLocation; via?: CampusLocation; to: CampusLocation }
  highlight?: { pickupId?: string | null; dropoffId?: string | null }
  onPick?: (lat: number, lng: number) => void
  className?: string
  label: string
}) {
  const center = useMemo<[number, number]>(() => {
    const hub = locations.find(isHub) ?? locations[0]
    return hub ? [hub.latitude, hub.longitude] : [10.3252, 123.9532]
  }, [locations])

  const fitPoints = useMemo<[number, number][]>(() => {
    const pts = route ? [route.from, route.via, route.to].filter(Boolean) : locations
    return (pts as CampusLocation[]).map((l) => [l.latitude, l.longitude])
  }, [route, locations])

  return (
    <div role="img" aria-label={label} className={cn('relative isolate overflow-hidden rounded-2xl bg-sunken', className)}>
      <MapContainer center={center} zoom={18} maxZoom={20} scrollWheelZoom={false} className="size-full" attributionControl>
        <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={20} maxNativeZoom={19} />
        <FitTo points={fitPoints} />
        {onPick ? <ClickCapture onPick={onPick} /> : null}
        {zones.map((z) => (
          <Circle
            key={z.id}
            center={[z.latitude, z.longitude]}
            radius={z.radius_meters}
            pathOptions={{ color: z.is_active ? '#EF5C74' : '#94A3C4', weight: 2, fillOpacity: z.is_active ? 0.18 : 0.06, dashArray: z.is_active ? undefined : '4 4' }}
          >
            <Tooltip>
              {z.name}
              {z.is_active ? '' : ' (inactive)'}
            </Tooltip>
          </Circle>
        ))}
        {route ? (
          <Polyline
            positions={[route.from, route.via, route.to].filter(Boolean).map((l) => [l!.latitude, l!.longitude] as [number, number])}
            pathOptions={{ color: '#4FB1F6', weight: 3, dashArray: '6 6' }}
          />
        ) : null}
        {locations.map((l) => {
          const kind = isHub(l) ? 'hub' : l.id === highlight?.dropoffId ? 'drop' : l.id === highlight?.pickupId ? 'vendor' : 'stop'
          return (
            <Marker key={l.id} position={[l.latitude, l.longitude]} icon={pin(kind)} keyboard={false}>
              <Tooltip direction="top" offset={[0, -12]}>
                {l.name}
                {kind === 'drop' ? ' · drop-off' : kind === 'vendor' ? ' · pickup' : ''}
              </Tooltip>
            </Marker>
          )
        })}
        {drones.map((d) => (
          <Marker key={d.id} position={[d.latitude, d.longitude]} icon={droneIcon(!!d.active)} zIndexOffset={1000} keyboard={false}>
            <Tooltip direction="top" offset={[0, -16]} permanent={!!d.active}>
              {d.label}
            </Tooltip>
          </Marker>
        ))}
      </MapContainer>
    </div>
  )
}
