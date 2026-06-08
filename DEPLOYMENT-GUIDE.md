# Staff Hub — Cloud Deployment Guide

This guide deploys your full stack so **no local IP configuration** is needed:

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│ Mobile App  │────▶│  staffhub-api    │────▶│ MongoDB     │
│ (Flutter)   │     │  (Render)        │     │ Atlas       │
└─────────────┘     └──────────────────┘     └─────────────┘
                           ▲
┌─────────────┐            │
│ CMS (Web)   │────────────┘
│ (Vercel)    │
└─────────────┘
```

---

## Step 1 — MongoDB Atlas (free tier)

1. Go to [mongodb.com/atlas](https://www.mongodb.com/atlas) and create a free cluster
2. **Database Access** → create a user with password
3. **Network Access** → Add IP Address → **Allow Access from Anywhere** (`0.0.0.0/0`)
4. **Connect** → Drivers → copy connection string:
   ```
   mongodb+srv://USER:PASSWORD@cluster0.xxxxx.mongodb.net/staffhub?retryWrites=true&w=majority
   ```
   Replace `USER`, `PASSWORD`, and keep database name `staffhub`

---

## Step 2 — Deploy API to Render

1. Push your code to GitHub (if not already)
2. Go to [render.com](https://render.com) → **New** → **Web Service**
3. Connect your GitHub repo
4. Settings:
   | Field | Value |
   |-------|-------|
   | Root Directory | `staffhub-api` |
   | Runtime | Node |
   | Build Command | `npm install` |
   | Start Command | `npm start` |
   | Health Check Path | `/api/health` |

5. **Environment Variables:**

   | Key | Value |
   |-----|-------|
   | `MONGODB_URI` | Your Atlas connection string |
   | `JWT_SECRET` | Long random string (e.g. generate at random.org) |
   | `ADMIN_SECRET` | Your admin registration secret |
   | `CORS_ORIGIN` | `https://your-cms.vercel.app` (add after Step 3) |
   | `WORKPLACE_LAT` | `1.5434665` |
   | `WORKPLACE_LNG` | `103.6123308` |
   | `WORKPLACE_RADIUS_METERS` | `60` |
   | `NODE_ENV` | `production` |

6. Click **Create Web Service**
7. Wait for deploy. Your API URL will be like:
   ```
   https://staffhub-api.onrender.com
   ```

8. Test in browser:
   ```
   https://staffhub-api.onrender.com/api/health
   ```
   Should return: `{"status":"ok","message":"Staff Hub API is running"}`

9. **Create first admin** (Postman or browser):
   ```
   POST https://staffhub-api.onrender.com/api/auth/register-admin
   Content-Type: application/json

   {
     "name": "Admin",
     "email": "admin@yourcompany.com",
     "password": "your-secure-password",
     "adminSecret": "admin123",
     "autoStaffId": true
   }
   ```

---

## Step 3 — Deploy CMS to Vercel

1. Go to [vercel.com](https://vercel.com) → **Add New Project**
2. Import your GitHub repo
3. **Root Directory** → set to `staffhub-cms`
4. **Environment Variables:**

   | Key | Value |
   |-----|-------|
   | `NEXT_PUBLIC_API_URL` | `https://staffhub-api.onrender.com/api` |

5. Click **Deploy**
6. Your CMS URL will be like: `https://staffhub-cms.vercel.app`

7. **Update API CORS** on Render:
   - Go to Render → your API service → Environment
   - Set `CORS_ORIGIN` to your Vercel URL:
     ```
     https://staffhub-cms.vercel.app
     ```
   - Save (Render will redeploy)

8. Open CMS → login with admin email/password from Step 2

---

## Step 4 — Build mobile app for production

No more local IP! Build APK with your cloud API URL:

```bash
cd staffhub-mobile
flutter build apk --release --dart-define=PRODUCTION_API_URL=https://staffhub-api.onrender.com/api
```

APK location:
```
staffhub-mobile/build/app/outputs/flutter-apk/app-release.apk
```

Install on any phone — it connects to the cloud API automatically.

---

## Architecture summary

| Component | Host | URL example |
|-----------|------|-------------|
| Database | MongoDB Atlas | `mongodb+srv://...` |
| API | Render | `https://staffhub-api.onrender.com` |
| CMS | Vercel | `https://staffhub-cms.vercel.app` |
| Mobile | User's phone | Points to Render API |

---

## Local development (still works)

| Component | Command |
|-----------|---------|
| API | `cd staffhub-api && npm run dev` |
| CMS | `cd staffhub-cms && npm run dev` |
| Mobile (emulator) | `flutter run` |
| Mobile (physical) | `flutter run --dart-define=API_HOST=192.168.x.x` |

---

## Troubleshooting

### CMS shows login error
- Check `NEXT_PUBLIC_API_URL` ends with `/api`
- Check API health URL works in browser
- Check `CORS_ORIGIN` on Render includes your Vercel domain (no trailing slash)

### Mobile app cannot connect
- Rebuild APK with correct `PRODUCTION_API_URL`
- Test API health URL on phone browser
- Render free tier sleeps after 15 min — first request may take ~30s

### MongoDB connection failed
- Check Atlas IP whitelist includes `0.0.0.0/0`
- Check username/password in connection string
- URL-encode special characters in password

### Port 3000 already in use (local)
```powershell
netstat -ano | findstr :3000
taskkill /PID <number> /F
```

---

## Cost (free tier)

| Service | Free tier |
|---------|-----------|
| MongoDB Atlas | 512 MB storage |
| Render | 750 hrs/month (sleeps when idle) |
| Vercel | Hobby plan for personal projects |

For production/demo with no sleep, upgrade Render to a paid plan (~$7/month).
