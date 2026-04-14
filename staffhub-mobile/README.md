# Staff Hub Mobile

Aplikasi Flutter untuk clock in/clock out dengan validasi radius 60m.

## Setup

1. Pastikan API berjalan (`staffhub-api`)
2. Ubah URL API dalam `lib/config.dart`:
   - Emulator Android: `http://10.0.2.2:3000/api`
   - iOS Simulator: `http://localhost:3000/api`
   - Peranti fizikal: `http://<IP_KOMPUTER>:3000/api` (guna `ipconfig`)

3. Jalankan:
```bash
flutter pub get
flutter run
```

## Permissions

- Lokasi (GPS) - untuk semak jarak dari tempat kerja
- Internet - untuk hubung ke API

## Build APK

```bash
flutter build apk --release
```
