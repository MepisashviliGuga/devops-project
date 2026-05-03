# DevOps CI/CD Project

A full DevOps pipeline demo: Node.js web app → GitHub Actions CI → Bash-powered IaC → Blue-Green CD → health monitoring.

---

## Tech Stack

| Layer | Tool |
|---|---|
| Web Application | Node.js 20 + Express 4 |
| Unit Testing | Jest 29 + Supertest |
| Linting | ESLint 8 |
| Version Control | Git (main + dev branches) |
| CI | GitHub Actions |
| IaC / CD | Bash scripts (Git Bash on Windows) |
| Deployment strategy | Blue-Green with automatic rollback |
| Monitoring | Bash health-check script + log file |

---

## Project Structure

```
devops-project/
├── app/
│   ├── server.js          # Express web application
│   ├── package.json
│   ├── .eslintrc.json
│   └── tests/
│       └── server.test.js # Jest unit tests
├── .github/
│   └── workflows/
│       └── ci.yml         # GitHub Actions CI pipeline
├── scripts/
│   ├── setup.sh           # IaC — single-command environment setup
│   ├── blue-green-deploy.sh
│   ├── rollback.sh
│   └── health-check.sh
├── .gitignore
└── README.md
```

---

## CI/CD Workflow Diagram

```mermaid
flowchart TD
    A([Developer pushes code]) --> B[GitHub Repository]
    B --> C{Branch?}
    C -- main or dev --> D[GitHub Actions Triggered]
    C -- PR to main --> D
    D --> E[Install Dependencies\nnpm install]
    E --> F[ESLint Linting\nnpm run lint]
    E --> G[Jest Unit Tests\nnpm test]
    F -- PASS --> H{Both pass?}
    G -- PASS --> H
    F -- FAIL --> Z([Pipeline Failed — block merge])
    G -- FAIL --> Z
    H -- YES --> I([CI Green — safe to deploy])
    I --> J[bash scripts/blue-green-deploy.sh]
    J --> K[Start inactive slot\nBlue or Green]
    K --> L{Health check\nGET /health}
    L -- 200 OK --> M[Switch production traffic\nto new slot on :3000]
    L -- FAIL --> N([Auto-rollback — old slot stays active])
    M --> O[bash scripts/health-check.sh]
    O --> P[(logs/health-check.log)]
    M --> Q[bash scripts/rollback.sh\nif manual rollback needed]
```

---

## Prerequisites

- **Node.js 20+** — https://nodejs.org/
- **Git for Windows** (includes Git Bash + curl) — https://git-scm.com/
- A **GitHub account** with an empty repository created

Verify in Git Bash:
```bash
node --version   # v20.x.x
npm --version    # 10.x.x
git --version    # git version 2.x
curl --version   # curl 8.x
```

---

## Step-by-Step Setup Guide

### Step 1 — Clone / initialise the repository

```bash
# In Git Bash, navigate to your project folder
cd ~/Desktop

# Initialise git and set up branches
git init devops-project
cd devops-project
git checkout -b main
```

Copy all project files into this folder, then:

```bash
git add .
git commit -m "feat: initial project structure with app, CI, and scripts"
```

### Step 2 — Create and push to GitHub

1. Go to **https://github.com/new** and create an empty repository (no README, no .gitignore).
2. Copy the repository URL (e.g. `https://github.com/your-username/devops-project.git`).

```bash
git remote add origin https://github.com/YOUR_USERNAME/devops-project.git
git push -u origin main
```

### Step 3 — Create the dev branch

```bash
git checkout -b dev
git push -u origin dev
```

> **Screenshot 1** — Take now: open your GitHub repository in the browser, click the branch dropdown, and capture the **main** and **dev** branches listed.

---

### Step 4 — IaC: Single-Command Environment Setup

In Git Bash from the project root:

```bash
bash scripts/setup.sh
```

This script:
- Checks Node.js, npm, curl, and git are installed
- Creates `logs/` and `scripts/pids/` directories
- Runs `npm install` inside `app/`
- Initialises deployment state files
- Creates `.env` with port configuration
- Runs the full test suite to verify everything works

> **Screenshot 2** — Take now: capture the **Git Bash terminal** showing the `setup.sh` output, from the "DevOps Project — Environment Setup" header all the way to "Setup Complete!" and the green test results.

---

### Step 5 — Run the application locally

```bash
cd app
npm start
```

Open **http://localhost:3000** in your browser.

> **Screenshot 3** — Take now: capture the **browser** showing the home page at `http://localhost:3000`. Then type your name in the form and submit it — capture the **JSON response** from `/greet/YourName`.

Stop the server with `Ctrl+C` before continuing.

---

### Step 6 — Trigger the CI pipeline

Make a small change on `dev` to trigger CI:

```bash
git checkout dev
# Edit app/server.js — e.g., change the <title> text slightly
git add app/server.js
git commit -m "feat: update page title on dev branch"
git push origin dev
```

Then open a **Pull Request** from `dev` → `main` on GitHub:
1. Go to your repo → **Pull requests** → **New pull request**
2. Base: `main`, Compare: `dev`
3. Click **Create pull request**

The CI pipeline will trigger automatically.

> **Screenshot 4** — Take now: go to your GitHub repo → **Actions** tab. Click the running workflow. Capture the **workflow summary page** showing the "Lint & Test" job with green checkmarks next to "Run ESLint" and "Run unit tests".

> **Screenshot 5** — Take now: go to your **Pull Request** page and capture the green "All checks have passed" status at the bottom of the PR.

Merge the PR:
```bash
# After merging on GitHub
git checkout main
git pull origin main
```

---

### Step 7 — Blue-Green Deployment (CD)

First start an initial "blue" production instance:

```bash
# From project root in Git Bash
SLOT=blue APP_VERSION=1.0.0 PORT=3000 node app/server.js &
echo $! > scripts/pids/prod.pid
```

Open **http://localhost:3000** — you should see **Version: 1.0.0 | Slot: blue**.

Now deploy a new "green" version:

```bash
bash scripts/blue-green-deploy.sh 2.0.0
```

The script will:
1. Start the new `green` slot on port 3002
2. Health-check it at `http://localhost:3002/health`
3. Stop the old production process
4. Start `green` on port 3000
5. Verify the switchover

> **Screenshot 6** — Take now: capture the **Git Bash terminal** showing the full `blue-green-deploy.sh` output, especially the lines:
> - "Deploying to : green (port 3002)"
> - "Health check PASSED on port 3002"
> - "Deployment Successful!"

> **Screenshot 7** — Take now: refresh **http://localhost:3000** in the browser and capture the updated page showing **Version: 2.0.0 | Slot: green**.

---

### Step 8 — Rollback

```bash
bash scripts/rollback.sh
```

> **Screenshot 8** — Take now: capture the **Git Bash terminal** showing:
> - "Current  : green"
> - "Rollback : blue"
> - "Rollback Successful! Active slot : blue -> http://localhost:3000"

Then refresh the browser and capture **http://localhost:3000** showing Slot: blue again.

---

### Step 9 — Health Check Monitoring

Open a **new** Git Bash window and run:

```bash
bash scripts/health-check.sh 10
```

This checks every 10 seconds and logs to `logs/health-check.log`.

Leave it running for ~1 minute to collect several entries, then check the log:

```bash
cat logs/health-check.log
```

> **Screenshot 9** — Take now: capture the **Git Bash terminal** running the health-check script showing multiple `OK | HTTP 200` lines with timestamps.

> **Screenshot 10** — Take now: in a second terminal, run `cat logs/health-check.log` and capture the **log file contents**.

**Simulate a failure:** Stop the app with `Ctrl+C`, wait 30 seconds, then capture the `FAIL | HTTP 000` lines appearing.

---

## Application Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/` | Home page with input form |
| GET | `/greet/:name` | Dynamic route — JSON greeting |
| POST | `/greet` | Form submission (redirects to `/greet/:name`) |
| GET | `/health` | Health check — returns JSON with status, version, slot |

---

## Running Tests Manually

```bash
cd app
npm test
```

Expected output: **12 tests passing** across 5 test suites.

```bash
npm run lint
```

Expected output: no ESLint errors.

---

## Port Reference

| Port | Purpose |
|---|---|
| 3000 | Production (always the live URL) |
| 3001 | Blue slot (inactive standby) |
| 3002 | Green slot (inactive standby) |

---

## Screenshots Summary

| # | What to capture | When |
|---|---|---|
| 1 | GitHub branch dropdown showing `main` and `dev` | After Step 3 |
| 2 | Git Bash: full `setup.sh` output | After Step 4 |
| 3 | Browser: home page + `/greet/Name` JSON | After Step 5 |
| 4 | GitHub Actions: workflow run with green checkmarks | After Step 6 CI |
| 5 | GitHub PR: "All checks have passed" banner | After Step 6 PR |
| 6 | Git Bash: full `blue-green-deploy.sh` output | After Step 7 |
| 7 | Browser: http://localhost:3000 showing Slot: green | After Step 7 |
| 8 | Git Bash: `rollback.sh` output showing success | After Step 8 |
| 9 | Git Bash: health-check monitor running with OK lines | After Step 9 |
| 10 | Terminal: `cat logs/health-check.log` output | After Step 9 |

---

## Troubleshooting

**Port already in use:**
```bash
# Find and kill process on a port (Git Bash)
netstat -ano | grep :3000
taskkill //PID <pid> //F
```

**npm command not found:**  
Make sure Node.js is installed and added to PATH. Restart Git Bash after installing.

**curl: command not found:**  
Use Git for Windows installer and ensure "Use Git and optional Unix tools from the Command Prompt" is selected.

**Health check returns 000:**  
The app is not running. Start it first:
```bash
cd app && npm start
```
