# Staff Hub - Panduan Setup Step-by-Step

Ikut langkah ini mengikut turutan.

---

## Bahagian 1: Setup MongoDB

### Opsyen A — MongoDB Tempatan (Local)

1. **Pasang MongoDB** jika belum ada  
   - Muat turun: https://www.mongodb.com/try/download/community  
   - Pilih Windows, MSI, install sebagai Service  

2. **Pastikan MongoDB berjalan**  
   - Tekan `Win + R`, taip `services.msc`, Enter  
   - Cari "MongoDB", pastikan status = Running  
   - Jika belum: Klik kanan → Start  

3. **Uji dengan MongoDB Compass (pilihan)**  
   - Buka MongoDB Compass  
   - Klik "+ Add new connection"  
   - Taip: `mongodb://localhost:27017`  
   - Klik Connect  

### Opsyen B — MongoDB Atlas (Cloud, percuma)

1. Daftar di https://cloud.mongodb.com  
2. Create Cluster → pilih Free tier  
3. **Database Access** → Add New Database User  
   - Username & password (simpan password)  
4. **Network Access** → Add IP Address  
   - Pilih "Allow Access from Anywhere" (0.0.0.0/0)  
5. **Connect** pada cluster → "Connect using MongoDB Compass"  
6. Salin connection string (simpan untuk Langkah 2)

---

## Bahagian 2: Setup API (Backend)

### Langkah 1: Sediakan fail .env

1. Buka PowerShell  
2. Jalankan:

```powershell
cd "C:\Users\User\Documents\Degree UTM\Staffhub-fyp"
Copy-Item "staffhub-api\.env.example" "staffhub-api\.env"
```

3. Buka fail `staffhub-api\.env` dengan editor  

### Langkah 2: Edit .env

**Untuk MongoDB tempatan**, pastikan:
```
MONGODB_URI=mongodb://localhost:27017/staffhub
```

**Untuk MongoDB Atlas**, gantikan MONGODB_URI dengan:
```
MONGODB_URI=mongodb+srv://USERNAME:PASSWORD@cluster0.xxxxx.mongodb.net/staffhub?retryWrites=true&w=majority
```
- Gantikan USERNAME dengan nama user database  
- Gantikan PASSWORD dengan password sebenar  
- Pastikan `/staffhub` ada sebelum `?`  

**Ubah JWT_SECRET** (wajib):
```
JWT_SECRET=rahsia-saya-super-secret-123
```
(Guna apa sahaja string panjang)  

Simpan fail .env.

### Langkah 3: Jalankan API

1. Buka PowerShell  
2. Jalankan:

```powershell
cd "C:\Users\User\Documents\Degree UTM\Staffhub-fyp\staffhub-api"
npm install
npm run dev
```

3. Tunggu sampai keluar mesej:
   ```
   MongoDB connected: localhost
   Server running on http://localhost:3000
   ```

4. **Jangan tutup** tetingkap PowerShell — biarkan API berjalan  

5. Uji: Buka browser → http://localhost:3000/api/health  
   - Patut nampak: `{"status":"ok","message":"Staff Hub API is running"}`  

---

## Bahagian 3: Setup & Jalankan App Flutter

### Langkah 1: Semak config.dart

Fail `staffhub-mobile\lib\config.dart` patut ada:
```dart
static const String apiBaseUrl = 'http://localhost:3000/api';
```

- **Chrome/Web**: `http://localhost:3000/api` (sudah betul)  
- **Emulator Android**: tukar ke `http://10.0.2.2:3000/api`  
- **Device fizikal**: tukar ke `http://IP-KOMPUTER-ANDA:3000/api`  

### Langkah 2: Jalankan app

1. Buka **PowerShell baru** (biarkan API terus berjalan di tetingkap pertama)  
2. Jalankan:

```powershell
cd "C:\Users\User\Documents\Degree UTM\Staffhub-fyp\staffhub-mobile"
flutter pub get
flutter run -d chrome
```

Atau double-click `JALANKAN-APP.bat`  

3. Tunggu app terbuka dalam Chrome  

---

## Bahagian 4: Uji Aplikasi

### Daftar Admin (pertama kali)

1. Dalam app, klik **"Register as Admin"**  
2. Isi:
   - Admin ID: `admin001`  
   - Full Name: Nama anda  
   - Email: `admin@staffhub.com` (atau email lain)  
   - Password: min 6 aksara  
   - Admin Secret: `admin123`  

3. Klik **Create Admin**  
4. Jika berjaya, anda akan masuk ke Admin Dashboard  

### Login sebagai Admin

1. Logout jika anda sudah login  
2. Klik **Sign In**  
3. Masukkan email & password admin yang baru daftar  
4. Klik **Sign In** — anda akan dibawa ke Admin Dashboard  

### Daftar Staff (untuk uji clock in/out)

1. Logout dari admin  
2. Klik **Register** (bukan Register as Admin)  
3. Isi Staff ID, Name, Email, Password  
4. Selepas daftar, anda boleh clock in/out dari Home  

---

## Ringkasan Urutan

| # | Tindakan | Status |
|---|----------|--------|
| 1 | MongoDB berjalan (local atau Atlas) | |
| 2 | Fail .env wujud dan betul | |
| 3 | Jalankan API (`npm run dev`) | |
| 4 | Jalankan app (`flutter run -d chrome`) | |
| 5 | Daftar admin → Login → Uji | |

---

## Google Maps API Key (untuk peta di homepage)

Peta menggunakan Google Maps. Anda perlu API key:

1. Pergi ke [Google Cloud Console](https://console.cloud.google.com/)
2. Buat projek baru atau pilih projek sedia ada
3. Enable **Maps JavaScript API** (untuk web) dan **Maps SDK for Android** (untuk Android)
4. Create Credentials → API Key
5. Gantikan `YOUR_GOOGLE_MAPS_API_KEY` di:
   - `staffhub-mobile/web/index.html` (baris script Google Maps)
   - `staffhub-mobile/android/app/src/main/AndroidManifest.xml` (meta-data API_KEY)

---

## Masalah biasa

| Masalah | Penyelesaian |
|---------|--------------|
| API stuck / timeout | Pastikan API dijalankan sebelum buka app |
| MongoDB connection failed | Semak MONGODB_URI dalam .env |
| Register admin stuck | Pastikan API berjalan, semak config.dart URL |
| CORS error (web) | API sudah ada cors() — pastikan URL betul |
| Peta kosong / kelabu | Tambah Google Maps API key di index.html dan AndroidManifest |

---

**Nota:** Sentiasa jalankan API dahulu, kemudian baru jalankan app Flutter.
