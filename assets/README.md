# Assets

Declared in `pubspec.yaml` and bundled with the app.

## `fonts/` — Inter

Real Inter font files (SIL Open Font License 1.1, see `OFL.txt`).

Source: [rsms/inter](https://github.com/rsms/inter) `v4.0`, file
`docs/font-files/InterVariable.ttf`.

> **Note:** all four declared weights (`Regular`, `Medium`, `SemiBold`,
> `Bold`) currently point at the variable font binary. Flutter does not
> automatically select named instances from a variable font, so heavier
> weights render from the default instance until static per-weight TTFs
> replace these files. Visual weight differences will be approximated by
> the framework's synthetic bolding only after static files are dropped in.

## `images/`, `icons/`

Placeholder assets so the asset bundle referenced by `pubspec.yaml` is
complete and `flutter build` / `flutter test` succeed. Replace with real
artwork as the UI is built out (audit finding F-18 tracks the placeholder
screens).

- `images/logo.png` — 1×1 transparent PNG placeholder
- `icons/app_icon.png` — 1×1 transparent PNG placeholder
