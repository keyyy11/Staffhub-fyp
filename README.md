# Staff Hub

Sistem kehadiran staff dengan clock in/clock out berasaskan lokasi (radius 60m).

## Tech Stack

- **Mobile**: Flutter
- **Backend**: Node.js (Express)
- **Database**: MongoDB

## Struktur Projek

```
Staffhub-fyp/
├── staffhub-api/      # Backend API (Node.js + Express + MongoDB)
├── staffhub-cms/      # Admin web CMS (Next.js — deploy to Vercel)
└── staffhub-mobile/   # Aplikasi Flutter
```

**Production deployment:** See [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) — host API on Render, CMS on Vercel, database on MongoDB Atlas. No local IP needed.

## Cara Mula

### 1. Setup API (Backend)

```bash
cd staffhub-api
copy .env.example .env
# Edit .env - isi MONGODB_URI dan koordinat WORKPLACE_LAT, WORKPLACE_LNG
npm install
npm run dev
```

### 2. Setup MongoDB

Pastikan MongoDB berjalan. Anda boleh:
- Install MongoDB secara tempatan
- Guna MongoDB Atlas (cloud) - paste connection string dalam `.env`

### 3. Setup Mobile App

```bash
cd staffhub-mobile
# Edit lib/config.dart - ubah apiBaseUrl untuk peranti anda
flutter pub get
flutter run
```

### 4. Ubah Lokasi Kerja

Dalam `staffhub-api/.env`:
```
WORKPLACE_LAT=1.5589   # Latitud pejabat
WORKPLACE_LNG=103.6391 # Longitud pejabat
WORKPLACE_RADIUS_METERS=60
```

Guna Google Maps untuk dapatkan koordinat: klik kanan pada lokasi > koordinat.

## API Endpoints

| Method | Endpoint | Keterangan |
|--------|----------|------------|
| POST | /api/attendance/clock-in | Clock in (hadir) |
| POST | /api/attendance/clock-out | Clock out (pulang) |
| GET | /api/attendance/workplace | Maklumat lokasi kerja |
| GET | /api/attendance/my/:staffId | Rekod kehadiran |
