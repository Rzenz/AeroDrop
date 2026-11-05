import * as Menu from '@radix-ui/react-dropdown-menu'
import { Download, Menu as MenuIcon, Moon, Sun } from 'lucide-react'
import { Link, NavLink, useLocation } from 'react-router-dom'
import { PLAY_STORE_URL } from '@/lib/config'
import { setTheme, useTheme } from '@/lib/theme'
import { cn } from '@/lib/utils'
import { Logo } from './brand'
import { IconButton } from './ui/button'

const links = [
  { to: '/about', label: 'About Us' },
  { to: '/team', label: 'Meet the Team' },
]

const linkClass = ({ isActive }: { isActive: boolean }) =>
  cn('rounded-lg px-3 py-2 text-sm font-medium transition-colors duration-150', isActive ? 'text-ink' : 'text-ink-2 hover:text-ink')

/** Public site header: About Us, Meet the Team, Download now (when the Play listing is set). */
export function SiteHeader() {
  const theme = useTheme()
  const { pathname } = useLocation()
  return (
    <header className="sticky top-0 z-30 bg-bg/80 pt-[env(safe-area-inset-top)] backdrop-blur-md">
      <div className="mx-auto flex h-16 max-w-6xl items-center gap-2 px-4 sm:px-6">
        <Logo />
        <nav aria-label="Main" className="ml-6 hidden items-center gap-1 lg:flex">
          {links.map((l) => (
            <NavLink key={l.to} to={l.to} className={linkClass}>
              {l.label}
            </NavLink>
          ))}
        </nav>

        <div className="ml-auto flex items-center gap-1.5">
          <IconButton className="hidden lg:grid" label={theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'} onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>
            {theme === 'dark' ? <Sun aria-hidden className="size-5" /> : <Moon aria-hidden className="size-5" />}
          </IconButton>
          {/* Use AeroDrop on the web instead of installing the app. Sign-in
              forwards visitors who are already signed in to their portal. */}
          <Link
            to="/sign-in"
            className="hidden h-10 items-center rounded-lg px-3 text-sm font-medium text-ink-2 underline-offset-4 transition-colors duration-150 hover:text-ink hover:underline lg:inline-flex"
          >
            Continue to a browser
          </Link>
          {PLAY_STORE_URL ? (
          <a
            href={PLAY_STORE_URL}
            target="_blank"
            rel="noreferrer"
            className="inline-flex h-10 items-center gap-2 rounded-xl bg-brand ps-3.5 pe-4 text-sm font-semibold text-on-brand shadow-sm transition-[transform,filter] duration-150 ease-out hover:brightness-110 active:scale-[0.96]"
          >
            <Download aria-hidden className="size-4" strokeWidth={2.25} />
            Download now
          </a>
          ) : null}

          {/* Below 1024px the page links, browser link and theme toggle move into
              this menu; the full row needs about 800px. */}
          <Menu.Root modal={false}>
            <Menu.Trigger asChild>
              <IconButton label="Open menu" className="lg:hidden">
                <MenuIcon aria-hidden className="size-5" />
              </IconButton>
            </Menu.Trigger>
            <Menu.Portal>
              <Menu.Content
                align="end"
                sideOffset={8}
                className="z-40 min-w-48 rounded-2xl bg-surface p-1.5 shadow-lg data-[state=closed]:animate-[fade-out_120ms_ease-in] data-[state=open]:animate-[dialog-in_180ms_cubic-bezier(0.16,1,0.3,1)]"
              >
                {/* Plain Links: Radix's asChild merges className as a string,
                    which breaks NavLink's className function. */}
                {links.map((l) => (
                  <Menu.Item key={l.to} asChild>
                    <Link
                      to={l.to}
                      aria-current={pathname === l.to ? 'page' : undefined}
                      className={cn('flex h-11 items-center rounded-xl px-3 text-sm font-medium outline-none data-[highlighted]:bg-sunken', pathname === l.to ? 'text-ink' : 'text-ink-2')}
                    >
                      {l.label}
                    </Link>
                  </Menu.Item>
                ))}
                <Menu.Item asChild>
                  <Link to="/sign-in" className="flex h-11 items-center rounded-xl px-3 text-sm font-medium text-ink-2 outline-none data-[highlighted]:bg-sunken">
                    Continue to a browser
                  </Link>
                </Menu.Item>
                <Menu.Separator className="mx-2 my-1 h-px bg-line" />
                <Menu.Item
                  onSelect={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
                  className="flex h-11 cursor-pointer items-center gap-2.5 rounded-xl px-3 text-sm font-medium text-ink-2 outline-none data-[highlighted]:bg-sunken"
                >
                  {theme === 'dark' ? <Sun aria-hidden className="size-4" /> : <Moon aria-hidden className="size-4" />}
                  {theme === 'dark' ? 'Light theme' : 'Dark theme'}
                </Menu.Item>
              </Menu.Content>
            </Menu.Portal>
          </Menu.Root>
        </div>
      </div>
    </header>
  )
}
