# 🚀 PocketPOS Deployment Strategy

## 🧩 Overview

This project uses a **two-repository deployment architecture**:

- **Repo B (`jaganathpanda/pocket-pos`)**
  - Development & source of truth
- **Repo A (`mypocketpos/mypocketpos`)**
  - Production hosting & deployment

---

## 📦 Repository Roles

### 🔹 Repo B (Development)
- Active development happens here
- Developers push code to `main` and `prod`
- Contains **sync workflow only**
- ❌ Does NOT deploy

---

### 🔹 Repo A (Production)
- Receives synced code from Repo B
- Contains **deployment workflow**
- Hosts live websites
- ✅ Only repo responsible for deployment

---

## 🌐 Environments

| Environment | Branch | Domain |
|------------|--------|--------|
| Staging | `main` | https://staging.mypocketpos.in |
| Production | `prod` | https://mypocketpos.in |

---

## 🔁 Deployment Flow

### 🧪 Staging Flow

```
Developer → Repo B (main)
        ↓
GitHub Action (sync-to-prod.yml)
        ↓
Repo A (main updated)
        ↓
Deploy workflow runs
        ↓
🌐 staging.mypocketpos.in updated
```

---

### 🚀 Production Flow

```
Developer → Merge main → prod (Repo B)
        ↓
GitHub Action (sync-to-prod.yml)
        ↓
Repo A (prod updated)
        ↓
Deploy workflow runs
        ↓
🌐 mypocketpos.in updated
```

---

## ⚙️ Workflows

### 🔹 Repo B Workflow

**File:** `.github/workflows/sync-to-prod.yml`

**Purpose:**
- Sync code to Repo A
- Remove internal workflow before pushing

**Key Behavior:**
- Runs on `main` and `prod`
- Uses Personal Access Token (PAT)
- Removes:
  `.github/workflows/sync-to-prod.yml`

---

### 🔹 Repo A Workflow

**File:** `.github/workflows/deploy_web.yml`

**Purpose:**
- Build and deploy website

**Behavior:**
- `main` → deploy to staging
- `prod` → deploy to production

---

## 🔐 Rules & Constraints

### ✅ Repo B
- No deployment
- No GitHub Pages
- Only sync logic

### ✅ Repo A
- Only deployment happens here
- No manual commits
- No sync workflow

---

## 🧠 Branch Strategy

```
main  → staging (testing)
prod  → production (live)
```

---

## 🔄 Developer Workflow

### Step 1: Push to Staging
```bash
git checkout main
git commit -m "feature update"
git push origin main
```

👉 Automatically deploys to:
https://staging.mypocketpos.in

---

### Step 2: Test Changes
- Validate features on staging site
- Fix issues if needed

---

### Step 3: Release to Production
```bash
git checkout prod
git merge main
git push origin prod
```

👉 Automatically deploys to:
https://mypocketpos.in

---

## 🛡️ Best Practices

- 🔒 Protect `prod` branch (no direct push)
- 🔁 Use Pull Requests for production releases
- 🧪 Always test on staging before production
- 🧹 Keep Repo A clean (no manual edits)

---

## ⚠️ Common Issues

| Issue | Cause |
|------|------|
| 403 Permission Denied | PAT missing or no access |
| github-actions[bot] used | PAT not applied |
| stale info error | Remote branch updated |
| workflow copied to Repo A | sync file not removed |

---

## 🏗️ Architecture Summary

```
Repo B (Development)
   ├── main  → staging
   └── prod  → production
        ↓
        (GitHub Action Sync)
        ↓
Repo A (Deployment)
   ├── main  → staging.mypocketpos.in
   └── prod  → mypocketpos.in
```

---

## 🎯 Final Outcome

- ✅ Safe staging before production
- ✅ Automated deployment pipeline
- ✅ Clean separation of responsibilities
- ✅ Reduced risk of production issues

---

## 📌 Notes

- Sync workflow is **never copied to Repo A**
- Repo A is the **single source of deployment**
- All deployments are **automated via GitHub Actions**
