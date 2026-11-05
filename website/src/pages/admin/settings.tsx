import { Bell, Moon, Plane, Scale, Wrench } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { Card, CardHeader, Switch } from '@/components/ui/primitives'
import { MAX_PAYLOAD_KG, MAX_TRIPS } from '@/lib/fees'
import { readLocal, writeLocal } from '@/lib/store'

// Console preferences, saved per browser. Dispatch, battery and weather
// rules live in the database functions, so nothing here changes the fleet.
export const ADMIN_PREFS_KEY = 'aerodrop-admin-prefs'
const defaults = { liveTelemetry: true }
const KEY = ADMIN_PREFS_KEY

export default function AdminSettings() {
  const [prefs, setPrefs] = useState(() => ({ ...defaults, ...readLocal(KEY, defaults) }))
  const set = (k: keyof typeof defaults) => (v: boolean) => {
    const next = { ...prefs, [k]: v }
    setPrefs(next)
    writeLocal(KEY, next)
  }

  return (
    <div className="grid max-w-4xl gap-6">
      <Card>
        <CardHeader title="System Settings" description="Configure global parameters and fleet defaults. Preferences save on this browser." />
        <div className="p-2" />
      </Card>
      <Section icon={<Moon />} title="Appearance">
        <Row title="Dark Color Theme" body="The admin console is always dark, as in the app.">
          <Switch label="Dark color theme" checked disabled onChange={() => undefined} />
        </Row>
      </Section>
      <Section icon={<Plane />} title="Fleet Operations">
        <Row title="Live Drone Telemetry" body="Move drones on the Command Deck radar every second between data refreshes.">
          <Switch label="Live drone telemetry" checked={prefs.liveTelemetry} onChange={set('liveTelemetry')} />
        </Row>
      </Section>
      <Section icon={<Bell />} title="Notifications & Alerts">
        <Row title="Admin alerts" body="Vendor applications, failed deliveries, low battery, weather changes and support reports always notify every admin.">
          <Link to="/admin/notifications" className="text-sm font-semibold text-brand-ink hover:underline">View</Link>
        </Row>
      </Section>
      <Section icon={<Scale />} title="Delivery Limits">
        <Row title="Global Max Payload" body={`System-wide maximum package weight per trip. Orders can use up to ${MAX_TRIPS} trips.`}>
          <span className="font-mono text-sm font-semibold text-ink">{MAX_PAYLOAD_KG} kg</span>
        </Row>
      </Section>
      <Section icon={<Wrench />} title="System">
        <Row title="Configure Campus Weather" body="Update flight safety constraints, temperature, and wind speed.">
          <Link to="/admin/weather" className="text-sm font-semibold text-brand-ink hover:underline">Open</Link>
        </Row>
      </Section>
    </div>
  )
}

function Section({ icon, title, children }: { icon: ReactNode; title: string; children: ReactNode }) {
  return (
    <Card>
      <div className="flex items-center gap-2 px-5 pt-5">
        <span className="text-brand [&_svg]:size-4" aria-hidden>{icon}</span>
        <h2 className="font-semibold text-ink">{title}</h2>
      </div>
      <div className="divide-y divide-line px-5 py-2">{children}</div>
    </Card>
  )
}

function Row({ title, body, children }: { title: string; body: string; children: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-6 py-3.5">
      <div>
        <p className="text-sm font-medium text-ink">{title}</p>
        <p className="text-sm text-ink-3">{body}</p>
      </div>
      {children}
    </div>
  )
}
