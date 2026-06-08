# Staff Hub CMS

Web admin panel for Staff Hub. Deploy on **Vercel** and connect to your cloud-hosted API — no local IP configuration needed.

## Features

- Dashboard with stats
- Staff management (register, edit, promote, salary)
- Branch management (multi-location geofencing)
- Attendance reports
- Leave approval + MC viewer
- Payslip management
- Discipline & warning letters
- Overtime audit (read-only)

## Local development

```bash
# 1. Start API + MongoDB
cd ../staffhub-api
npm run dev

# 2. Start CMS
cd ../staffhub-cms
cp .env.example .env.local
npm run dev
```

Open http://localhost:3001 (or the port Next.js shows). Login with an **admin** account.

## Environment variables

| Variable | Description |
|----------|-------------|
| `NEXT_PUBLIC_API_URL` | API base URL ending in `/api` |

Example `.env.local`:
```
NEXT_PUBLIC_API_URL=http://localhost:3000/api
```

## Deploy to Vercel

See [DEPLOYMENT-GUIDE.md](../DEPLOYMENT-GUIDE.md) for the full walkthrough.

Quick steps:
1. Deploy `staffhub-api` to Render (with MongoDB Atlas)
2. Push this repo to GitHub
3. Import `staffhub-cms` folder in Vercel
4. Set `NEXT_PUBLIC_API_URL=https://your-api.onrender.com/api`
5. Add Vercel URL to API `CORS_ORIGIN`
