# Architecture

See `docs/product-charter.md`.

MVC · single app target · no SPM packages.

```
RegionalCheck/
  App/       lifecycle, CarPlay, Theme
  Views/     HomeView, StatusView, StatusController
  Data/      models, Ubilling, location, region store
  Resources/
```

Shared `provider` / `location` / `regions` live in `RegionalCheckApp.swift` (`AppDependencies`) for phone + CarPlay.

Flow: GPS → Region → Ubilling → Normal / Attention / Checking / Unable to update

Smoke: `./scripts/smoke-tests.sh`
