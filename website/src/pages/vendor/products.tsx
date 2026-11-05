import { ImagePlus, Package, Pencil, Plus, Search, Trash2 } from 'lucide-react'
import { useEffect, useRef, useState, type FormEvent } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useMe } from '@/auth/auth'
import { AnimatedTabs } from '@/components/forgeui/animated-tabs'
import { Money } from '@/components/orders'
import { Button, IconButton } from '@/components/ui/button'
import { ConfirmDialog, Dialog } from '@/components/ui/dialog'
import { Skeleton } from '@/components/ui/loader'
import { Badge, Card, EmptyState, Field, Input, ProductArt, Switch, Textarea } from '@/components/ui/primitives'
import { toast } from '@/components/ui/toast'
import { api, type ProductInput } from '@/data/api'
import { MAX_PAYLOAD_KG } from '@/lib/fees'
import { errorMessage, invalidate, useQuery } from '@/lib/store'
import type { Product } from '@/types'

type Filter = 'all' | 'active' | 'low' | 'hidden'

export default function VendorProducts() {
  const me = useMe()
  const [params, setParams] = useSearchParams()
  const products = useQuery(() => api.products({ vendorId: me.id, includeInactive: true }), [me.id])
  const [q, setQ] = useState('')
  const [filter, setFilter] = useState<Filter>('all')
  const [editing, setEditing] = useState<Product | 'new' | null>(null)

  useEffect(() => {
    if (params.get('new')) {
      setEditing('new')
      setParams({}, { replace: true })
    }
  }, [params, setParams])

  const all = products.data ?? []
  const term = q.trim().toLowerCase()
  const shown = all.filter(
    (p) =>
      (!term || `${p.name} ${p.category}`.toLowerCase().includes(term)) &&
      (filter === 'all' || (filter === 'active' && p.is_active) || (filter === 'hidden' && !p.is_active) || (filter === 'low' && p.stock_quantity <= 5)),
  )

  async function toggle(p: Product, v: boolean) {
    try {
      await api.saveProduct({ ...toInput(p), is_active: v })
      invalidate()
      toast(v ? `${p.name} is visible to customers.` : `${p.name} is hidden from customers.`)
    } catch (e) {
      toast(errorMessage(e), 'error')
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
          <div className="relative sm:w-72">
            <Search aria-hidden className="pointer-events-none absolute top-1/2 left-3.5 size-4 -translate-y-1/2 text-ink-3" />
            <Input type="search" aria-label="Search products" placeholder="Search products" value={q} onChange={(e) => setQ(e.target.value)} className="pl-10" />
          </div>
          <AnimatedTabs
            label="Filter products"
            value={filter}
            onChange={setFilter}
            tabs={[
              { value: 'all', label: 'All', count: all.length },
              { value: 'active', label: 'Available' },
              { value: 'low', label: 'Low stock', count: all.filter((p) => p.stock_quantity <= 5).length },
              { value: 'hidden', label: 'Hidden' },
            ]}
          />
        </div>
        <Button icon={<Plus aria-hidden className="size-4" />} onClick={() => setEditing('new')}>
          Add Product
        </Button>
      </div>

      <Card className="overflow-hidden">
        {products.loading ? (
          <div className="space-y-2 p-4">{[0, 1, 2, 3].map((i) => <Skeleton key={i} className="h-16" />)}</div>
        ) : shown.length ? (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px] text-sm">
              <thead className="text-left text-xs text-ink-3">
                <tr className="shadow-[inset_0_-1px_0_var(--line)]">
                  <th scope="col" className="px-5 py-3 font-medium">Product</th>
                  <th scope="col" className="px-3 py-3 text-right font-medium">Price</th>
                  <th scope="col" className="px-3 py-3 text-right font-medium">Stock</th>
                  <th scope="col" className="px-3 py-3 text-right font-medium">Weight</th>
                  <th scope="col" className="px-3 py-3 font-medium">Available</th>
                  <th scope="col" className="px-5 py-3 text-right font-medium"><span className="sr-only">Actions</span></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {shown.map((p) => (
                  <tr key={p.id} className="hover:bg-sunken/50">
                    <td className="px-5 py-3">
                      <div className="flex items-center gap-3">
                        <div className="size-11 shrink-0 overflow-hidden rounded-lg">
                          <ProductArt name={p.name} src={p.image_url} className="text-xs" />
                        </div>
                        <div className="min-w-0">
                          <p className="truncate font-medium text-ink">{p.name}</p>
                          <p className="text-xs text-ink-3">{p.category ?? 'Uncategorised'}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-3 py-3 text-right"><Money value={p.price} /></td>
                    <td className="px-3 py-3 text-right tabular-nums">
                      {p.stock_quantity <= 0 ? <Badge tone="danger">Out</Badge> : p.stock_quantity <= 5 ? <Badge tone="warning">{p.stock_quantity}</Badge> : p.stock_quantity}
                    </td>
                    <td className="px-3 py-3 text-right text-ink-2 tabular-nums">{p.weight_grams} g</td>
                    <td className="px-3 py-3"><Switch label={`${p.name} available`} checked={p.is_active} onChange={(v) => toggle(p, v)} /></td>
                    <td className="px-5 py-3">
                      <div className="flex justify-end gap-1">
                        <IconButton label={`Edit ${p.name}`} onClick={() => setEditing(p)}><Pencil aria-hidden className="size-4" /></IconButton>
                        <ConfirmDialog
                          trigger={<IconButton label={`Delete ${p.name}`}><Trash2 aria-hidden className="size-4" /></IconButton>}
                          title={`Delete ${p.name}?`}
                          body="It disappears from your store. Past orders keep their record. To pause sales instead, switch it off."
                          confirmLabel="Delete product"
                          onConfirm={async () => {
                            try {
                              await api.deleteProduct(p.id)
                              invalidate()
                              toast('Product deleted.')
                            } catch (e) {
                              toast(errorMessage(e), 'error')
                            }
                          }}
                        />
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState icon={<Package aria-hidden className="size-5" />} title={all.length ? 'No products match' : 'No products yet'} body={all.length ? undefined : 'Add your first product so customers can order it.'} action={all.length ? undefined : <Button onClick={() => setEditing('new')}>Add Product</Button>} />
        )}
      </Card>

      <ProductDialog product={editing} onClose={() => setEditing(null)} />
    </div>
  )
}

const toInput = (p: Product): ProductInput => ({
  id: p.id, name: p.name, description: p.description ?? '', price: p.price, stock_quantity: p.stock_quantity,
  category: p.category ?? '', weight_grams: p.weight_grams, image_url: p.image_url, is_active: p.is_active,
})

function ProductDialog({ product, onClose }: { product: Product | 'new' | null; onClose: () => void }) {
  const isNew = product === 'new'
  const [form, setForm] = useState({ name: '', description: '', price: '', stock: '', category: '', weight: '', image: '', active: true })
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [busy, setBusy] = useState(false)
  const [uploading, setUploading] = useState(false)
  const fileInput = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (!product) return
    if (product === 'new') setForm({ name: '', description: '', price: '', stock: '', category: '', weight: '', image: '', active: true })
    else setForm({ name: product.name, description: product.description ?? '', price: String(product.price), stock: String(product.stock_quantity), category: product.category ?? '', weight: String(product.weight_grams), image: product.image_url ?? '', active: product.is_active })
    setErrors({})
  }, [product])

  const set = (k: keyof typeof form) => (e: { target: { value: string } }) => setForm((f) => ({ ...f, [k]: e.target.value }))

  async function submit(e: FormEvent) {
    e.preventDefault()
    const err: Record<string, string> = {}
    const price = Number(form.price)
    const stock = Number(form.stock)
    const weight = Number(form.weight)
    if (form.name.trim().length < 2) err.name = 'Enter a product name.'
    if (!(price > 0)) err.price = 'Enter a price above ₱0.'
    if (!Number.isInteger(stock) || stock < 0) err.stock = 'Use a whole number, 0 or more.'
    if (!Number.isInteger(weight) || weight <= 0) err.weight = 'Enter the weight in grams.'
    else if (weight > MAX_PAYLOAD_KG * 1000) err.weight = `One item can’t exceed the drone payload of ${MAX_PAYLOAD_KG * 1000} g.`
    if (form.image && !/^(https?:|blob:)/.test(form.image)) err.image = 'Upload the photo again.'
    setErrors(err)
    if (Object.keys(err).length) return
    setBusy(true)
    try {
      await api.saveProduct({
        id: isNew ? undefined : (product as Product).id,
        name: form.name.trim(), description: form.description.trim(), price, stock_quantity: stock,
        category: form.category.trim(), weight_grams: weight, image_url: form.image.trim() || null, is_active: form.active,
      })
      invalidate()
      toast(isNew ? 'Product added.' : 'Product updated.')
      onClose()
    } catch (e2) {
      setErrors({ form: errorMessage(e2) })
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={!!product} onOpenChange={(v) => !v && onClose()} title={isNew ? 'Add product' : 'Edit product'} description="Weight decides how many drone trips an order needs.">
      <form onSubmit={submit} noValidate className="grid gap-4 sm:grid-cols-2">
        <Field label="Name" error={errors.name} className="sm:col-span-2">{(p) => <Input {...p} value={form.name} onChange={set('name')} />}</Field>
        <Field label="Price (₱)" error={errors.price}>{(p) => <Input {...p} inputMode="decimal" value={form.price} onChange={set('price')} />}</Field>
        <Field label="Stock" error={errors.stock}>{(p) => <Input {...p} inputMode="numeric" value={form.stock} onChange={set('stock')} />}</Field>
        <Field label="Weight (grams)" error={errors.weight}>{(p) => <Input {...p} inputMode="numeric" value={form.weight} onChange={set('weight')} />}</Field>
        <Field label="Category">{(p) => <Input {...p} value={form.category} onChange={set('category')} placeholder="Coffee" />}</Field>
        <div className="flex items-center gap-4 sm:col-span-2">
          <ProductArt name={form.name || 'Product'} src={form.image || null} className="size-20 shrink-0 rounded-2xl text-xs" />
          <div className="flex flex-col items-start gap-1.5">
            <div className="flex flex-wrap gap-2">
              <Button type="button" size="sm" variant="secondary" loading={uploading} icon={<ImagePlus aria-hidden className="size-4" />} onClick={() => fileInput.current?.click()}>
                {form.image ? 'Change photo' : 'Upload photo'}
              </Button>
              {form.image ? <Button type="button" size="sm" variant="ghost" onClick={() => setForm((f) => ({ ...f, image: '' }))}>Remove</Button> : null}
            </div>
            <p className={errors.image ? 'text-xs font-medium text-danger' : 'text-xs text-ink-3'}>{errors.image || 'Optional. JPEG, PNG or WebP, up to 5 MB.'}</p>
          </div>
          <input
            ref={fileInput}
            type="file"
            accept="image/jpeg,image/png,image/webp"
            className="sr-only"
            tabIndex={-1}
            aria-hidden
            onChange={async (e) => {
              const file = e.target.files?.[0]
              e.target.value = ''
              if (!file) return
              setUploading(true)
              setErrors((x) => ({ ...x, image: '' }))
              try {
                // product-images/<vendor uid>/prod_<ms>.<ext>, like the app's add-product screen
                const url = await api.uploadProductImage(file)
                setForm((f) => ({ ...f, image: url }))
              } catch (err) {
                setErrors((x) => ({ ...x, image: errorMessage(err) }))
              } finally {
                setUploading(false)
              }
            }}
          />
        </div>
        <Field label="Description" className="sm:col-span-2">{(p) => <Textarea {...p} value={form.description} onChange={set('description')} maxLength={400} />}</Field>
        <label className="flex items-center justify-between gap-3 rounded-xl bg-sunken px-4 py-3 sm:col-span-2">
          <span className="text-sm font-medium text-ink">Available to customers</span>
          <Switch label="Available to customers" checked={form.active} onChange={(v) => setForm((f) => ({ ...f, active: v }))} />
        </label>
        {errors.form ? <p role="alert" className="rounded-xl bg-danger-bg px-4 py-3 text-sm text-danger sm:col-span-2">{errors.form}</p> : null}
        <div className="flex justify-end gap-2 sm:col-span-2">
          <Button variant="ghost" onClick={onClose}>Cancel</Button>
          <Button type="submit" loading={busy}>{isNew ? 'Add product' : 'Save changes'}</Button>
        </div>
      </form>
    </Dialog>
  )
}
