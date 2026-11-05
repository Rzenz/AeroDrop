import { Check, Plus } from 'lucide-react'
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { addToCart, useCart } from '@/lib/cart'
import { formatPeso } from '@/lib/format'
import { cn } from '@/lib/utils'
import type { Product } from '@/types'
import { ProductArt, Rating } from './ui/primitives'
import { toast } from './ui/toast'

export function ProductCard({ product, vendorName }: { product: Product; vendorName: string }) {
  const cart = useCart()
  const inCart = cart.find((i) => i.productId === product.id)?.quantity ?? 0
  const [justAdded, setJustAdded] = useState(false)
  const out = product.stock_quantity <= 0
  const atLimit = inCart >= product.stock_quantity

  return (
    <div className="group flex flex-col overflow-hidden rounded-2xl bg-surface shadow-md">
      <Link to={`/user/products/${product.id}`} className="relative block aspect-[4/3] overflow-hidden bg-sunken">
        <ProductArt name={product.name} src={product.image_url} className="transition-transform duration-300 ease-out group-hover:scale-[1.03]" />
        {out ? <span className="absolute top-3 left-3 rounded-full bg-black/80 px-2.5 py-1 text-xs font-semibold text-white">Sold out</span> : product.stock_quantity <= 5 ? <span className="absolute top-3 left-3 rounded-full bg-warning-bg px-2.5 py-1 text-xs font-semibold text-warning">{product.stock_quantity} left</span> : null}
      </Link>
      <div className="flex flex-1 flex-col p-4">
        <Link to={`/user/products/${product.id}`} className="font-semibold text-ink hover:underline">
          {product.name}
        </Link>
        <p className="mt-0.5 text-xs text-ink-3">
          {product.category} · {product.weight_grams} g
        </p>
        <div className="mt-auto flex items-center justify-between gap-2 pt-3">
          <div>
            <p className="font-display text-lg font-bold text-ink tabular-nums">{formatPeso(product.price)}</p>
            <Rating value={product.rating} count={product.review_count} />
          </div>
          <button
            type="button"
            disabled={out || atLimit}
            aria-label={out ? `${product.name} is sold out` : `Add ${product.name} to cart`}
            onClick={() => {
              addToCart(product, vendorName)
              setJustAdded(true)
              setTimeout(() => setJustAdded(false), 1200)
              toast(`${product.name} added to cart.`)
            }}
            className={cn(
              'relative grid size-11 place-items-center rounded-xl bg-brand text-on-brand shadow-sm transition-[transform,opacity] duration-150 ease-out active:scale-[0.96] disabled:opacity-40',
            )}
          >
            {/* Icon swap: scale 0.25→1, opacity, 4px blur (better-ui) */}
            <Plus aria-hidden className={cn('absolute size-5 transition-[scale,opacity,filter] duration-200 ease-[cubic-bezier(0.2,0,0,1)]', justAdded ? 'scale-25 opacity-0 blur-[4px]' : 'scale-100 opacity-100 blur-none')} />
            <Check aria-hidden className={cn('absolute size-5 transition-[scale,opacity,filter] duration-200 ease-[cubic-bezier(0.2,0,0,1)]', justAdded ? 'scale-100 opacity-100 blur-none' : 'scale-25 opacity-0 blur-[4px]')} />
            {inCart > 0 ? <span className="absolute -top-1.5 -right-1.5 grid min-w-5 place-items-center rounded-full bg-surface px-1 text-[11px] leading-5 font-bold text-brand-ink shadow-sm tabular-nums">{inCart}</span> : null}
          </button>
        </div>
      </div>
    </div>
  )
}
