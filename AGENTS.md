# AGENTS.md

Perro Look: Flutter booking app for a Bogotá dog-grooming salon ("estética canina"). Supabase backend, Spanish UI.

## Commands

- `flutter pub get`
- `.\run.ps1 [device] [port]` (PowerShell) or `./run.sh` (Git Bash) — default Chrome on port 5000.
- `flutter analyze`
- `flutter test`; one file: `flutter test test/salon_time_test.dart`; one test: `flutter test --plain-name "texto o parte del nombre"`.
- Regenerate launcher icon / native splash: `dart run flutter_launcher_icons` / `dart run flutter_native_splash:create`.
- No CI, no codegen, no state-management package. UI is plain `StatefulWidget` plus constructor injection.

`run.ps1`/`run.sh` exist because Flutter has no project-level default args. A bare `flutter run` silently uses sample data instead of the backend. Before running against Supabase, copy `env/example.json` to `env/dev.json` and fill `SUPABASE_URL` and `SUPABASE_ANON_KEY`. `.vscode/launch.json` already passes the flag.

On this Windows machine, `flutter`/`dart` may be blocked by Device Guard (`dart.exe ha sido bloqueado...`). Report that; do not rewrite the app to avoid Flutter.

## Structure

- `lib/main.dart` → `lib/app.dart` → `SplashScreen` → `HomeScreen`; `AppBootstrap` has a hard 5-second startup deadline.
- `lib/core/`: config, theme, date/money/phone formatting, navigation transitions, Bogotá time.
- `lib/features/booking/`: 3-step booking flow (service, day/time, identification by name + mobile + pet), models, repositories. `lib/features/admin/`: owner agenda and email/password sign-in. `lib/features/home/`, `splash/`.
- Each data area follows: `abstract interface` → `Sample*` implementation → `Supabase*` implementation → `default*Repository()` selecting on `AppConfig.hasSupabase`. Tests and keyless runs use `Sample*`.

## Backend and config invariants

- Configuration is compile-time: `--dart-define-from-file=env/dev.json`. `AppConfig` uses `String.fromEnvironment`, which only works in a `const` context; removing `const` silently yields empty strings.
- Never add a `try/catch` that falls back to sample data when Supabase is configured. With keys and a broken backend the app shows an error and retry, deliberately: invented free slots cause real overbookings. Without keys, sample data is the expected mode.
- `citas` rows are never inserted directly. The app books through the `reservar_cita_por_celular` RPC (no session needed): the client is identified by mobile number, not by `auth.uid()`; it finds or creates the `perfiles` row (accountless clients allowed, `perfiles.id` is not an FK to `auth.users`) and the pet, never renames an existing profile, and calls the internal `crear_cita_para`, which recalculates price and duration from `servicios`. The admin "Cliente nuevo" form uses the same RPC. `crear_cita_para` has `execute` revoked from `anon`/`authenticated`; every new function in `public` needs an explicit `revoke`/`grant` because Supabase grants `anon` and `authenticated` separately. Slots are protected by a Postgres GiST exclusion constraint; error `23P01` maps to `SlotTakenException`.
- Admin access is decided by the `admins` table + `es_admin()` and enforced by RLS. Do not enforce authorization in the client.
- SQL order: files in `supabase/migrations/` lexicographically, then `supabase/seed.sql`. `reset.sql` wipes everything for a retry. Apply in the Supabase dashboard SQL Editor; no Supabase CLI/Docker is assumed.
- `lib/core/time/salon_time.dart` is the only timezone boundary: fixed Bogotá UTC-5. Never use `toLocal()` or device-local time for appointments; use `enHoraEstetica`, `desdeHoraEstetica`, `hoyEnLaEstetica`.
- `anon` key is public by design; RLS protects data. Never put `service_role` in the client.

## Conventions

- User-facing strings and comments are Spanish; identifiers mix Spanish and English. Money is integer COP.
- Slot grid is 45 minutes. Services are one principal plus optional extras; price/duration live in `ServiceCatalog` (currently sample values).
- Styling belongs in `lib/core/theme/app_theme.dart` and `app_colors.dart`. Archivo is a variable font: use `AppTheme.archivo(...)`, which sets both `fontWeight` and `FontVariation('wght', ...)`.
- Tests are offline by design. Inject repositories and fixed dates into widgets; use a fixed Monday such as `DateTime(2026, 11, 2)` because sample availability derives busy slots from the date.
- `env/dev.json` is gitignored; only `env/example.json` is versioned.
- `supabase/README.md` documents schema, RLS and admin setup. `assets/images/README.md` documents logo constraints and replacement rules.
