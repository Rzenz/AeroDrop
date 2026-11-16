import type { PinnedDropoff } from '@/components/dropoff-map-picker'
import { createStore, useStore } from './store'

/**
 * Where the next order goes when it isn't a campus building: the one place
 * the pin lives, shared by the home "Deliver to" chooser and checkout so the
 * two can never disagree. Kept for the tab's session only and never written
 * to the profile: a pin has no campus_location_id.
 *
 * `pin` is the last confirmed pin; `mode` says whether it is in use. Checkout
 * switching to a campus point keeps the pin for a quick switch back; choosing
 * a building in the header forgets it.
 */
export interface DropoffChoice {
  mode: 'campus' | 'pin'
  pin: PinnedDropoff | null
}

const initial: DropoffChoice = { mode: 'campus', pin: null }
export const dropoffChoice = createStore<DropoffChoice>(initial)
export const useDropoffChoice = () => useStore(dropoffChoice)

/** A confirmed pin, from either place: it becomes the drop-off. */
export const choosePin = (pin: PinnedDropoff) => dropoffChoice.set({ mode: 'pin', pin })
/** Back to the campus point; the pin stays for a quick switch back (checkout's radio). */
export const chooseCampusPoint = () => dropoffChoice.set((c) => ({ ...c, mode: 'campus' }))
/** A building chosen in the header, or sign-out: the pin is gone. */
export const forgetPin = () => dropoffChoice.set(initial)
