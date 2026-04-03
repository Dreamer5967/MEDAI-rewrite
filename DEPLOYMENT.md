# MedAI — Vercel Deployment Guide

## Bugs Fixed in This Repo

| # | Bug | Fix Applied |
|---|-----|-------------|
| 1 | `emergentintegrations` package (private, not on PyPI) caused install failures | Replaced with official `anthropic` SDK |
| 2 | `secure=False` on cookies — broken authentication over HTTPS in production | `secure` flag now reads `ENVIRONMENT` env var |
| 3 | Hardcoded `/app/memory/` path → crash on Vercel/Railway | Removed file write from startup |
| 4 | In-memory `chat_instances` dict → lost on every serverless cold start | Chat history now rebuilt from MongoDB per request |
| 5 | Invalid/pinned model `claude-sonnet-4-5-20250929` | Updated to `claude-haiku-4-5-20251001` |
| 6 | `@emergentbase/visual-edits` private URL dep broke CI installs | Removed from `package.json` |
| 7 | `requirements.txt` had 100+ packages including unneeded ML/Google libs | Slimmed to 12 essential packages |

---

## Architecture

```
Vercel Project
├── /api/index.py        ← Python serverless (FastAPI)  → handles /api/*
└── /frontend/build/     ← React static build           → handles everything else
         |
         └── MongoDB Atlas (external)
```

---

## Prerequisites

- [Vercel account](https://vercel.com) (free tier works)
- [MongoDB Atlas account](https://mongodb.com/atlas) (free M0 cluster works)
- [Anthropic API key](https://console.anthropic.com)
- Git repo (GitHub / GitLab / Bitbucket)

---

## Step 1 — MongoDB Atlas Setup

1. Go to [MongoDB Atlas](https://cloud.mongodb.com) → **Create a free M0 cluster**
2. **Database Access** → Add a user with username + password → note them down
3. **Network Access** → Add IP `0.0.0.0/0` (allow all — required for Vercel serverless)
4. **Connect** → **Connect your application** → copy the connection string

   It looks like:
   ```
   mongodb+srv://myuser:mypassword@cluster0.abcde.mongodb.net/?retryWrites=true&w=majority
   ```

---

## Step 2 — Push to GitHub

```bash
git init
git add .
git commit -m "initial commit"
git remote add origin https://github.com/YOUR_USERNAME/medai.git
git push -u origin main
```

---

## Step 3 — Deploy to Vercel

### 3a. Import the project

1. Go to [vercel.com/new](https://vercel.com/new)
2. Click **Import Git Repository** → select your repo
3. Vercel will detect the `vercel.json` automatically

### 3b. Configure the build settings

In the **Configure Project** screen:

| Field | Value |
|-------|-------|
| Framework Preset | **Other** (auto-detected via vercel.json) |
| Root Directory | `.` (leave as root) |
| Build Command | *(leave blank — vercel.json handles it)* |
| Output Directory | *(leave blank)* |

### 3c. Set Environment Variables

Click **Environment Variables** and add every one of these:

| Variable | Example Value | Required |
|----------|--------------|----------|
| `MONGO_URL` | `mongodb+srv://user:pass@cluster0.xyz.mongodb.net/` | ✅ |
| `DB_NAME` | `medai` | ✅ |
| `JWT_SECRET` | *(run `python -c "import secrets; print(secrets.token_hex(32))"`)* | ✅ |
| `ANTHROPIC_API_KEY` | `sk-ant-api03-...` | ✅ |
| `ADMIN_EMAIL` | `admin@yourdomain.com` | ✅ |
| `ADMIN_PASSWORD` | *(strong password)* | ✅ |
| `CORS_ORIGINS` | `https://YOUR-APP.vercel.app` | ✅ |
| `ENVIRONMENT` | `production` | ✅ |
| `REACT_APP_BACKEND_URL` | `https://YOUR-APP.vercel.app` | ✅ |

> ⚠️ `REACT_APP_BACKEND_URL` must be set **before the build step** because
> Create React App bakes it into the bundle at build time.
> Since the frontend and backend live in the same Vercel project,
> `REACT_APP_BACKEND_URL` = your Vercel project URL (same origin).

### 3d. Deploy

Click **Deploy**. First deploy takes ~3 minutes.

---

## Step 4 — Verify the Deployment

Once deployed, open `https://your-app.vercel.app`:

1. **Landing page** should load
2. **Register** a new account
3. **Dashboard** → describe symptoms → AI analysis should work
4. **Chat** with the AI assistant

Test the backend directly:
```
GET  https://your-app.vercel.app/api/symptoms
POST https://your-app.vercel.app/api/auth/register
```

---

## Step 5 — Custom Domain (Optional)

1. Vercel Dashboard → your project → **Settings → Domains**
2. Add your domain (e.g. `medai.yourdomain.com`)
3. Update `CORS_ORIGINS` env var to include your custom domain

---

## Alternative: Separate Frontend + Backend Deployment

If the monorepo Vercel setup is too complex, deploy them separately:

### Backend → Railway

1. Go to [railway.app](https://railway.app) → **New Project → Deploy from GitHub**
2. Select your repo, set **Root Directory** to `backend`
3. Railway auto-detects the `Procfile`
4. Add the same environment variables (without `REACT_APP_*` ones)
5. Note your Railway URL (e.g. `https://medai-api.railway.app`)

### Frontend → Vercel

1. New Vercel project → set **Root Directory** to `frontend`
2. **Framework**: Create React App
3. **Build Command**: `craco build`
4. **Output Directory**: `build`
5. Set `REACT_APP_BACKEND_URL=https://medai-api.railway.app`

---

## Local Development

```bash
# 1. Backend
cd backend
cp ../.env.example .env          # fill in your values
pip install -r requirements.txt
uvicorn server:app --reload --port 8000

# 2. Frontend (new terminal)
cd frontend
cp .env.example .env             # set REACT_APP_BACKEND_URL=http://localhost:8000
yarn install
yarn start
```

Open http://localhost:3000

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Build fails: `Module not found` | Missing env var baked into React build | Add `REACT_APP_BACKEND_URL` in Vercel env vars **before** deploying |
| 500 on `/api/*` | Missing env vars on backend | Check Vercel → Functions → Logs |
| Login works but auth lost on reload | Cookie `samesite`/`secure` mismatch | Make sure `ENVIRONMENT=production` is set |
| MongoDB connection timeout | Atlas Network Access blocking Vercel IPs | Set Network Access to `0.0.0.0/0` |
| `ANTHROPIC_API_KEY` not found | Env var missing or wrong name | Set `ANTHROPIC_API_KEY` (not `EMERGENT_LLM_KEY`) |
| Chat session loses history | Expected — history rebuilds from DB | Working as designed (serverless-safe) |
