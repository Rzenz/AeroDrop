import { useEffect } from 'react'

export function usePageTitle(title: string) {
  useEffect(() => {
    document.title = `${title} · AeroDrop`
    return () => {
      document.title = 'AeroDrop · Campus drone delivery'
    }
  }, [title])
}
