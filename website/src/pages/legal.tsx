import { ArrowLeft } from 'lucide-react'
import { Link } from 'react-router-dom'
import { Logo } from '@/components/brand'

// Text copied from the app's privacy_policy_page.dart and
// terms_conditions_page.dart so both say the same thing.
const content = {
  privacy: {
    title: 'Privacy Policy',
    sections: [
      ['1. Information Collection', 'AeroDrop collects basic user account profile details (Name, Email, and Department) and location specifications during flight dispatch requests. Live telemetry and flight coordinate parameters are audited solely for campus airspace coordination.'],
      ['2. Use of Information', 'The collected specifications are utilized strictly to orchestrate automated drone dispatches, ensure proper package delivery to platforms, audit operator access roles, and prevent unauthorized airspace access.'],
      ['3. Airspace Safety & Security', 'We do not share any user metrics or coordinates with external third-party agencies. All flight logs and payload histories are stored locally inside UCLM secure servers and are subjected to role-based access restrictions.'],
    ],
  },
  terms: {
    title: 'Terms & Conditions',
    sections: [
      // The app's copy says 5.0 kg; the system limit is 0.5 kg per trip.
      ['1. Payload Responsibilities', 'Users are solely responsible for verifying that their delivery items do not exceed the 0.5 kg per-trip maximum weight threshold and are non-hazardous, dry, and securely sealed before handing them to the drone deck loader.'],
      ['2. Automated Flight Paths', 'Flights are controlled by autonomous autopilot firmware following safe campus corridors. Users must not interfere with flight corridors, geofenced areas, or attempt unauthorized remote commands.'],
      ['3. Liability and Accidents', 'UCLM and the drone fleet logistics team hold final authority for flight overrides. In the event of emergency landing, payload recovery will be handled by the nearest designated fleet support ground crew.'],
    ],
  },
}

export default function Legal({ page }: { page: keyof typeof content }) {
  const c = content[page]
  return (
    <div className="min-h-dvh bg-bg px-4 py-6 sm:px-6">
      <div className="mx-auto max-w-2xl">
        <Logo />
        <Link to="/" className="mt-10 inline-flex items-center gap-1.5 text-sm font-semibold text-ink-2 hover:text-ink">
          <ArrowLeft aria-hidden className="size-4" /> Home
        </Link>
        <h1 className="mt-4 font-display text-4xl font-extrabold text-ink">{c.title}</h1>
        <div className="mt-8 space-y-6">
          {c.sections.map(([h, body]) => (
            <section key={h} className="rounded-2xl bg-surface p-6 shadow-md">
              <h2 className="font-semibold text-ink">{h}</h2>
              <p className="mt-2 text-ink-2">{body}</p>
            </section>
          ))}
        </div>
      </div>
    </div>
  )
}

export function NotFound() {
  return (
    <div className="grid min-h-dvh place-items-center bg-bg px-4 text-center">
      <div>
        <p className="font-mono text-sm text-ink-3">404</p>
        <h1 className="mt-2 font-display text-3xl font-extrabold text-ink">This page flew off</h1>
        <p className="mt-2 text-ink-2">The link may be old, or the page moved.</p>
        <Link to="/" className="mt-6 inline-flex h-11 items-center rounded-xl bg-brand px-5 font-semibold text-on-brand">
          Back home
        </Link>
      </div>
    </div>
  )
}
