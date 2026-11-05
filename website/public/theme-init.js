// Apply the saved or system theme before first paint, so there is no flash.
// A separate file (not inline) so the Content-Security-Policy can forbid inline scripts.
try {
  var t = localStorage.getItem('aerodrop-theme')
  if (t !== 'light' && t !== 'dark') {
    t = matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
  }
  document.documentElement.dataset.theme = t
  document.querySelector('meta[name=theme-color]').content = t === 'dark' ? '#000000' : '#ffffff'
} catch (e) {}
