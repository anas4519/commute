# Commute

A personal Android app that compares walking, car and two-wheeler times for saved routes, e.g. Home → Metro A vs Home → Metro B. It uses the Google Routes API (`computeRouteMatrix`) and Places API (New). Everything is stored on the device.

## Setup

1. **Google Cloud project**: enable billing, then enable **Routes API** and **Places API (New)**.
2. **Create an API key** under APIs & Services → Credentials, then restrict it:
   - *Application restriction*: Android apps → package `com.anas.commute` + SHA-1 of your signing cert.
     Debug SHA-1: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android | grep SHA1`
   - *API restriction*: Routes API, Places API (New) only.
   - The app sends `X-Android-Package` / `X-Android-Cert` headers, which is how Google applies Android restrictions to REST calls.
3. **Safety net** (optional but recommended): set a daily quota cap on Routes elements and a small budget alert.
4. **Keys file** (git-ignored):
   ```
   cp env/keys.example.json env/keys.json   # then fill in key + SHA-1 (colons OK)
   ```
5. **Run**
   ```
   flutter pub get
   flutter run --dart-define-from-file=env/keys.json
   flutter build apk --release --dart-define-from-file=env/keys.json   # add the release SHA-1 to the key too
   ```

## How it works
- On open or resume, it fetches only stale cells: car and bike after 3 min, walking after 24 h. Pull-to-refresh forces car and bike (debounced to 30 s).
- One matrix request per mode. Pairs are grouped by origin, or sent as a single full matrix when that bills fewer elements (`lib/core/matrix_planner.dart`).
- Errors are shown per cell ("n/a"). Offline or key errors show a banner with the last results.
- Places search uses one session token per picker (autocomplete → details) and a minimal field mask. The Paste tab accepts `lat, lng`, Google Maps URLs, and `maps.app.goo.gl` short links.
- Bicycle mode is off by default (Settings) because coverage in India is limited.

## Tests
`flutter analyze && flutter test`
