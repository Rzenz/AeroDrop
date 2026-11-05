import type { CartItem, Product } from '@/types'
import { createStore, readLocal, useStore, writeLocal } from './store'

const KEY = 'aerodrop-cart'
export const cartStore = createStore<CartItem[]>(readLocal<CartItem[]>(KEY, []))
cartStore.subscribe(() => writeLocal(KEY, cartStore.get()))

export const useCart = () => useStore(cartStore)
export const cartCount = (items: CartItem[]) => items.reduce((s, i) => s + i.quantity, 0)

export function addToCart(p: Product, vendorName: string, qty = 1) {
  cartStore.set((items) => {
    const hit = items.find((i) => i.productId === p.id)
    if (hit) return items.map((i) => (i === hit ? { ...i, quantity: Math.min(i.quantity + qty, p.stock_quantity) } : i))
    return [
      ...items,
      { productId: p.id, productName: p.name, vendorId: p.vendor_id, vendorName, imageUrl: p.image_url, unitPrice: p.price, weightGrams: p.weight_grams, quantity: Math.min(qty, p.stock_quantity), stock: p.stock_quantity },
    ]
  })
}

export const setQuantity = (productId: string, quantity: number) =>
  cartStore.set((items) =>
    quantity <= 0 ? items.filter((i) => i.productId !== productId) : items.map((i) => (i.productId === productId ? { ...i, quantity: Math.min(quantity, i.stock) } : i)),
  )

export const removeFromCart = (productId: string) => cartStore.set((items) => items.filter((i) => i.productId !== productId))
export const clearVendor = (vendorId: string) => cartStore.set((items) => items.filter((i) => i.vendorId !== vendorId))

/** The checkout places one order per vendor, as place_order takes one vendor. */
export function groupByVendor(items: CartItem[]) {
  const groups = new Map<string, { vendorId: string; vendorName: string; items: CartItem[] }>()
  for (const i of items) {
    const g = groups.get(i.vendorId) ?? { vendorId: i.vendorId, vendorName: i.vendorName, items: [] }
    g.items.push(i)
    groups.set(i.vendorId, g)
  }
  return [...groups.values()]
}
