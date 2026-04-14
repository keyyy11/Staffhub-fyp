# Staff Hub API

Backend API untuk sistem kehadiran staff dengan validasi lokasi (radius 60m).

## Setup

1. Pastikan MongoDB berjalan
2. Copy `.env.example` ke `.env` dan isi nilai
3. Jalankan:

```bash
npm install
npm run dev
```

## API Endpoints

| Method | Endpoint | Keterangan |
|--------|----------|------------|
| POST | `/api/attendance/clock-in` | Clock in (hadir) |
| POST | `/api/attendance/clock-out` | Clock out (pulang) |
| GET | `/api/attendance/workplace` | Maklumat lokasi kerja |
| GET | `/api/attendance/my/:staffId` | Rekod kehadiran staff |

## Clock In/Out Request Body

```json
{
  "staffId": "staff001",
  "lat": 1.5589,
  "lng": 103.6391
}
```

## Ubah Lokasi Kerja

Edit `.env`:
```
WORKPLACE_LAT=1.5589
WORKPLACE_LNG=103.6391
WORKPLACE_RADIUS_METERS=60
```
