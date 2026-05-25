# RoTree plugin preview

A faithful HTML mockup of the Studio plugin window. Colors and layout come
straight from `plugin/src/UI/Theme.luau` and `plugin/src/UI/MainWindow.luau`.

## View on iPhone (or any browser)

Open one of these URLs in Safari:

- **Direct (via raw.githack)**:  
  `https://raw.githack.com/Akrapovich13k/RoTree/main/docs/preview/index.html`
- **Via githubusercontent.com**: doesn't render HTML, use the link above instead.
- **GitHub Pages** (if you enable it on this repo): publish from `main` /
  `/docs` and the preview will live at
  `https://akrapovich13k.github.io/RoTree/preview/`.

## What's inside

- The full plugin window: header, all cards (Bridge / Exports / Last export
  / AI Context / Rojo / Patch Safety / Appearance), footer.
- Working light & dark mode (tap the pill at the top OR the in-widget toggle).
- Working toggle switches (Watch mode, Safe Mode, Auto-apply, Dark mode).
- Mobile-safe layout (viewport meta, safe-area-inset padding for iPhone notch).

What this is **not**: a live plugin. The buttons don't trigger exports —
this is purely visual so you can confirm the look before testing in Studio.
