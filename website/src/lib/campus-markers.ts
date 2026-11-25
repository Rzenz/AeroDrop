import L from 'leaflet'
import type { CampusLocation } from '@/types'

// The test drop-off (migration 42) is a field-test point, not a campus
// building. It keeps the role colours but is drawn as a rounded square with a
// flask, so in a demo it reads at a glance as a test point.
export const isTestPoint = (l: CampusLocation) => l.location_code === 'TEST-DROP'
const FLASK =
  '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M10 2v7.31L4.2 19.4A1.75 1.75 0 0 0 5.72 22h12.56a1.75 1.75 0 0 0 1.52-2.6L14 9.31V2"/><path d="M8.5 2h7"/><path d="M7 16h10"/></svg>'

/** The live map's marker art (campus-map.tsx), shared with the drop-off picker. */
export const pin = (kind: 'hub' | 'stop' | 'drop' | 'vendor', test = false) =>
  L.divIcon({
    className: '',
    iconSize: [28, 28],
    iconAnchor: [14, 14],
    html: `<span style="display:grid;place-items:center;width:28px;height:28px;border-radius:${test ? '7px' : '999px'};background:${
      kind === 'hub' ? '#19223B' : kind === 'drop' ? '#3A6FD4' : kind === 'vendor' ? '#2BBE8A' : '#ffffff'
    };box-shadow:0 0 0 2px ${kind === 'stop' ? '#3A6FD4' : '#ffffff'},0 4px 10px rgba(0,0,0,.25);color:${kind === 'stop' ? '#3A6FD4' : '#fff'};font:700 11px Inter,sans-serif">${
      test ? FLASK : kind === 'hub' ? 'H' : kind === 'drop' ? '▼' : kind === 'vendor' ? '◆' : '•'
    }</span>`,
  })
