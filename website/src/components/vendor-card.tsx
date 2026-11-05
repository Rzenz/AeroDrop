import { MapPin } from 'lucide-react'
import { Link } from 'react-router-dom'
import type { CampusLocation, Vendor } from '@/types'
import { Avatar, Badge, Rating } from './ui/primitives'

export function VendorCard({ vendor, location }: { vendor: Vendor; location?: CampusLocation | null }) {
  return (
    <Link
      to={`/user/vendors/${vendor.id}`}
      className="group flex h-full flex-col rounded-2xl bg-surface p-4 shadow-md transition-[transform,box-shadow] duration-150 ease-out hover:-translate-y-0.5 hover:shadow-lg active:scale-[0.98]"
    >
      <div className="flex items-center gap-3">
        <Avatar name={vendor.business_name} src={vendor.business_logo_url} size={48} className="rounded-xl" />
        <div className="min-w-0 flex-1">
          <p className="truncate font-semibold text-ink">{vendor.business_name}</p>
          <Rating value={vendor.rating} count={vendor.review_count} />
        </div>
      </div>
      {vendor.business_description ? <p className="mt-3 line-clamp-2 text-sm text-ink-2">{vendor.business_description}</p> : null}
      <div className="mt-auto flex flex-wrap items-center gap-2 pt-4">
        {vendor.business_category ? <Badge tone="info">{vendor.business_category}</Badge> : null}
        {location ? (
          <span className="inline-flex items-center gap-1 text-xs text-ink-3">
            <MapPin aria-hidden className="size-3.5" />
            {location.name.replace(/^UCLM /, '')}
          </span>
        ) : null}
      </div>
    </Link>
  )
}
