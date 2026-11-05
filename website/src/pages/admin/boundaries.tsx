import { MapPinned, Plus, Trash2 } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { CampusMap } from '@/components/campus-map'
import { Button, IconButton } from '@/components/ui/button'
import { ConfirmDialog, Dialog } from '@/components/ui/dialog'
import { Skeleton } from '@/components/ui/loader'
import { Badge, Card, CardHeader, EmptyState, Field, Input, Switch, Textarea } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { api } from '@/data/api'
import { findHub } from '@/lib/flight'
import { errorMessage, invalidate, useQuery } from '@/lib/store'
import type { NoFlyZone } from '@/types'

type Draft = Omit<NoFlyZone, 'id'> & { id?: string }

export default function FlightBoundaries() {
  const zones = useQuery(() => api.zones())
  const locations = useQuery(() => api.locations())
  const [draft, setDraft] = useState<Draft | null>(null)

  const blank = (lat?: number, lng?: number): Draft => {
    const hub = locations.data ? findHub(locations.data) : null
    return { name: '', description: '', latitude: lat ?? hub?.latitude ?? 10.3252, longitude: lng ?? hub?.longitude ?? 123.9532, radius_meters: 25, is_active: true }
  }

  async function toggle(z: NoFlyZone, v: boolean) {
    try {
      await api.saveZone({ ...z, is_active: v })
      invalidate()
      toast(`${z.name} ${v ? 'enforced' : 'paused'}.`)
    } catch (e) {
      toast(errorMessage(e), 'error')
    }
  }

  return (
    <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_380px]">
      <Card className="overflow-hidden">
        <CardHeader title="Campus map" description="Click the map to place a new no-fly zone." className="pb-4" />
        {locations.data ? (
          <CampusMap label="Campus map with no-fly zones" locations={locations.data} zones={zones.data ?? []} onPick={(lat, lng) => setDraft(blank(lat, lng))} className="h-[520px] rounded-none" />
        ) : (
          <Skeleton className="h-[520px] rounded-none" />
        )}
      </Card>
      <Card className="self-start">
        <CardHeader title="No-fly zones" action={<Button size="sm" icon={<Plus aria-hidden className="size-4" />} onClick={() => setDraft(blank())}>Add</Button>} />
        <ul className="p-3">
          {(zones.data ?? []).map((z) => (
            <li key={z.id} className="flex items-center gap-3 rounded-xl px-2 py-3 hover:bg-sunken">
              <button type="button" onClick={() => setDraft(z)} className="min-w-0 flex-1 text-left">
                <span className="flex items-center gap-2">
                  <span className="truncate font-medium text-ink">{z.name}</span>
                  <Badge tone={z.is_active ? 'danger' : 'neutral'}>{z.is_active ? 'Active' : 'Paused'}</Badge>
                </span>
                <span className="block text-xs text-ink-3 tabular-nums">{z.radius_meters} m radius</span>
              </button>
              <Switch label={`Enforce ${z.name}`} checked={z.is_active} onChange={(v) => toggle(z, v)} />
              <ConfirmDialog
                trigger={<IconButton label={`Delete ${z.name}`}><Trash2 aria-hidden className="size-4" /></IconButton>}
                title={`Delete ${z.name}?`}
                body="Drones will be allowed over this area again."
                confirmLabel="Delete zone"
                onConfirm={async () => {
                  try {
                    await api.deleteZone(z.id)
                    invalidate()
                    toast('Zone deleted.')
                  } catch (e) {
                    toast(errorMessage(e), 'error')
                  }
                }}
              />
            </li>
          ))}
          {zones.data && !zones.data.length ? <EmptyState icon={<MapPinned aria-hidden className="size-5" />} title="No zones yet" body="Click the map to add one." /> : null}
        </ul>
      </Card>
      {draft ? <ZoneDialog key={draft.id ?? `${draft.latitude},${draft.longitude}`} draft={draft} onClose={() => setDraft(null)} /> : null}
    </div>
  )
}

function ZoneDialog({ draft, onClose }: { draft: Draft; onClose: () => void }) {
  const [form, setForm] = useState<Draft>(draft)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (form.name.trim().length < 2) return setError('Name the zone.')
    if (!(form.radius_meters >= 5 && form.radius_meters <= 500)) return setError('Use a radius between 5 and 500 metres.')
    setBusy(true)
    try {
      await api.saveZone({ ...form, name: form.name.trim() })
      invalidate()
      toast(form.id ? 'Zone updated.' : 'Zone added.')
      onClose()
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open onOpenChange={(v) => !v && onClose()} title={form.id ? 'Edit no-fly zone' : 'New no-fly zone'}>
      <form onSubmit={submit} noValidate className="grid gap-4 sm:grid-cols-2">
        <Field label="Name" className="sm:col-span-2">{(p) => <Input {...p} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />}</Field>
        <Field label="Latitude">{(p) => <Input {...p} inputMode="decimal" value={form.latitude} onChange={(e) => setForm({ ...form, latitude: Number(e.target.value) })} />}</Field>
        <Field label="Longitude">{(p) => <Input {...p} inputMode="decimal" value={form.longitude} onChange={(e) => setForm({ ...form, longitude: Number(e.target.value) })} />}</Field>
        <Field label="Radius (metres)">{(p) => <Input {...p} inputMode="numeric" value={form.radius_meters} onChange={(e) => setForm({ ...form, radius_meters: Number(e.target.value) })} />}</Field>
        <label className="flex items-center justify-between gap-3 self-end rounded-xl bg-sunken px-4 py-2.5">
          <span className="text-sm font-medium text-ink">Enforced</span>
          <Switch label="Enforced" checked={form.is_active} onChange={(v) => setForm({ ...form, is_active: v })} />
        </label>
        <Field label="Reason" className="sm:col-span-2" error={error}>{(p) => <Textarea {...p} value={form.description ?? ''} onChange={(e) => setForm({ ...form, description: e.target.value })} />}</Field>
        <div className="flex justify-end gap-2 sm:col-span-2">
          <Button variant="ghost" onClick={onClose}>Cancel</Button>
          <Button type="submit" loading={busy}>Save zone</Button>
        </div>
      </form>
    </Dialog>
  )
}
