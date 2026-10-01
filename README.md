# Ultio Project

A modern, containerized development workspace for **Frappe v15** and **ERPNext v15** applications, powered by VS Code Dev Containers, automated multi-site orchestration, and modular management scripts.

---

## 🚀 Quick Start (Minimal Steps to Run)

Get your bench and sites running with minimal friction:

### 1. Open the Environment

Ensure you have **Docker** and **VS Code** with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) installed (or use **GitHub Codespaces**).

```bash
# Clone the repository
git clone <repo-url> ultio-project
cd ultio-project

# Open in VS Code
code .
```

Press `Ctrl + Shift + P` (or `Cmd + Shift + P`) and run:
> **Dev Containers: Reopen in Container**

*Your host `~/.ssh` directory is mounted automatically into `/home/frappe/.ssh` inside the container for private GitLab repository access.*

### 2. Run the Installer

In the Dev Container integrated terminal:

```bash
cd /workspace/development
bash installer.sh
```

- **Bench Configuration**: Press `Enter` through the prompts to keep standard defaults (`frappe-bench`, `version-15`, `mariadb`, admin password `admin`).
- **Site Mode**: Select your target site (e.g. `coverage.json`, `alqamzi.json`, or `clean.localhost`).
- The installer automatically initializes the bench, fetches Git repositories, creates the site in MariaDB, executes automated headless setup, runs migrations, and compiles frontend assets.

### 3. Access Your Site

When `bench start` is running:

- **Browser URL**: `http://<site-name>:8000` (e.g. `http://coverage.localhost:8000` or `http://alqamzi.localhost:8000`)
- **Username**: `Administrator`
- **Password**: `admin` (or the password configured during setup)

---

## ⚡ Daily Commands (Cheat Sheet)

Run these inside `/workspace/development/frappe-bench`:

```bash
# Start bench services (web server, worker queues, scheduler, socketio)
bench start

# Stop bench
Ctrl + C

# Open Frappe interactive Python console for a specific site
bench --site <site-name> console

# Run database migrations for a site
bench --site <site-name> migrate

# Clear site cache
bench --site <site-name> clear-cache

# Build/compile frontend assets
bench build

# View installed apps on a site
bench --site <site-name> list-apps
```

---

## 🛠️ Interactive Installer (`installer.sh`) Deep-Dive

The installer script (`development/installer.sh`) is the primary setup orchestrator. It is completely interactive and handles environment initialization, app dependency gathering, and site deployment through a modular, conditional flow.

### Flow & Conditions Matrix

```text
┌─────────────────────────────────────────────────────────────┐
│ 1. Bench Configuration (skipped if frappe-bench exists)     │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ 2. App Fetch Selection                                      │
│    ├── Option 1: All apps from apps.json                    │
│    └── Option 2: Select specific apps (e.g. 1 2 5,8)        │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ 3. Setup Mode Selection                                     │
│    ├── [A] Configured Sites (scripts/sites/*.json)          │
│    │    ├── Select Configs: All OR specific subset          │
│    │    └── App Mode:                                       │
│    │         ├── 1) Install apps listed in site JSON        │
│    │         └── 2) Sites only (create DB, no extra apps)   │
│    ├── [B] Clean Site (creates clean.localhost, no apps)    │
│    └── [C] Apps Only (clones/registers apps, no sites)      │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ 4. Execution & Automated Headless Wizard Setup              │
└─────────────────────────────────────────────────────────────┘
```

### 1. Bench Settings & Prompts
When `frappe-bench` does not exist, the installer prompts for:
- **Bench directory name** (Default: `frappe-bench`): Local folder under `/workspace/development`.
- **Frappe git URL** (Default: `https://github.com/frappe/frappe`): Repository source for Frappe framework.
- **Frappe branch** (Default: `version-15`): Target branch initialized by `bench init`.
- **Python version** (Optional): Specific `pyenv` Python version override.
- **Node version** (Optional): Specific `nvm` Node version override.
- **Verbose bench init** (Default: `no`): Toggles detailed `bench init --verbose` logging.
- **Database type** (Default: `mariadb`): Select between `mariadb` and `postgresql`.
- **Site Administrator password** (Default: `admin`): Root desk password.

*Condition:* If `frappe-bench` already exists, these prompts are bypassed automatically and the existing bench is reused.

### 2. App Fetch Modes (`choose_apps`)
Reads `development/scripts/apps/apps.json`:
- **All apps**: Clones and registers every app entry found in `apps.json`.
- **Select apps**: Presents a numbered index of apps; accept space or comma-separated numbers (e.g., `1 3 7,12`) or type `all`. Generates an isolated temporary configuration for the run.

### 3. Site Setup Modes (`choose_site_mode`)
- **1) Use site JSON configs (`configured`)**: Deploys sites defined in `development/scripts/sites/*.json`.
  - **Config Selection**: Choose all site configs or specify a subset by index (e.g., `1 4,6`).
  - **App Mode (`choose_site_config_app_mode`)**:
    - `install`: Creates the site database, checks out exact app branches/tags declared in the site JSON, installs each app, runs migrations, and builds assets.
    - `sites_only`: Creates empty site databases named after the selected JSON configs without installing custom apps.
- **2) Create one clean site (`clean`)**: Creates an empty site (default name: `clean.localhost`) without custom apps.
- **3) Install selected apps only (`apps_only`)**: Clones and registers apps into the bench without creating or touching any sites.

---

## 🔄 App Branch & Tag Switcher (`switch-site-app-refs.sh`)

When working across multiple sites or features, you frequently need to switch existing apps to the branches and tags defined in a site profile **without reinstalling the site or destroying databases**.

`switch-site-app-refs.sh` provides this capability with strict safety checks.

### Purpose & Scope
- **What it does**: Reads a site JSON file, checks out the exact branch or tag for each app listed, and verifies repository clean state.
- **What it does NOT do**: It does **not** create databases, does **not** install apps with bench, and does **not** delete files.

### Safety Guards & Pre-conditions
1. **Uncommitted Changes Check**: For every app repository, it runs:
   ```bash
   git diff --quiet && git diff --cached --quiet
   ```
   If uncommitted, staged, or dirty changes are detected, **the script halts immediately** to protect your work from being overwritten. You must commit or stash changes before running again.
2. **Repository Existence Check**: Verifies that `$APPS_DIR/<app>/.git` exists. If an app has not been fetched yet, an error is reported.

### Usage & Input Options

#### Option A: Interactive Menu
Run with no arguments to pick from an indexed list of available site configurations:

```bash
cd /workspace/development
bash scripts/switch-site-app-refs.sh
```

#### Option B: Direct Argument
Pass a site profile name, JSON file name, or explicit file path:

```bash
# Pass config name directly
bash scripts/switch-site-app-refs.sh alqamzi

# Pass filename with extension
bash scripts/switch-site-app-refs.sh aljar.json

# Pass relative or absolute file path
bash scripts/switch-site-app-refs.sh scripts/sites/coverage.json
```

#### Option C: Custom Bench Directory
Override the target bench via `BENCH_DIR`:

```bash
BENCH_DIR=/path/to/custom-bench bash scripts/switch-site-app-refs.sh alqamzi
```

### Interactive Runtime Prompts
- **Fetch latest branches/tags before checkout (`FETCH_REFS`)** [Default: `Y/n`]: Runs `git fetch --all --tags --prune` on each app to ensure new remote tags or branches are visible locally before checking out.
- **Continue if one app fails (`CONTINUE_ON_ERROR`)** [Default: `y/N`]: Controls whether checkout errors on one app halt the entire process or allow continuing with remaining apps.

### Recommended Post-Switch Routine
After switching branches across apps, always run migrations and asset compilation:

```bash
cd /workspace/development/frappe-bench
bench --site <site-name> migrate
bench build
```

---

## 🦊 GitLab CLI (`glab`) & Merge Requests

The container includes the official **GitLab CLI (`glab`)** pre-installed and ready to interact with `git.fabrica-dev.com`.

### 1. Log in to `glab`

#### Step 1: Create a Personal Access Token (PAT)
1. Open your browser and go to:  
   **`https://git.fabrica-dev.com/-/user_settings/personal_access_tokens`**  
   *(Or click your avatar in GitLab &rarr; **Preferences** &rarr; **Access Tokens**)*
2. Set a name (e.g., `glab-cli`).
3. Check the following scopes:
   - [x] **`api`**
   - [x] **`read_repository`**
   - [x] **`write_repository`**
4. Click **Create personal access token** and copy the token.

---

#### Step 2: Log in using the Token flag
Pass the token directly via the `--token` flag to skip the OAuth Application prompt:

```bash
glab auth login --hostname git.fabrica-dev.com --token <YOUR_COPIED_TOKEN>
```

Alternatively, you can pass it via `stdin`:

```bash
glab auth login --hostname git.fabrica-dev.com --stdin
```
*(Paste your token and press **Enter**)*

---

#### Step 3: Verify Authentication
Check the authentication status:

```bash
glab auth status --hostname git.fabrica-dev.com
```

> **Tip for Docker / Bench environments:**  
> You can also authenticate without writing configuration files by setting environment variables in your `~/.bashrc`:
> ```bash
> export GITLAB_HOST="git.fabrica-dev.com"
> export GITLAB_TOKEN="<YOUR_COPIED_TOKEN>"
> ```

---

### 2. Creating Merge Requests with `glab`

To create two Merge Requests (one targeting `develop` and one targeting `main`) using `glab`, follow these steps:

#### Step 1: Make sure you are in the app folder and push your branches
First, navigate to your app directory:
```bash
cd /workspace/development/frappe-bench/apps/handover
```

Make sure both branches are pushed to GitLab:
```bash
git push -u origin <your-develop-branch>
git push -u origin <your-main-branch>
```

---

#### Step 2: Create the Merge Requests with `glab`
You can specify `--source-branch` and `--target-branch` directly without even having to switch branches:

##### 1. MR targeting `develop`:
```bash
glab mr create \
  --source-branch <your-develop-branch> \
  --target-branch develop \
  --title "Your MR title for develop" \
  --description "Description of changes"
```

##### 2. MR targeting `main`:
```bash
glab mr create \
  --source-branch <your-main-branch> \
  --target-branch main \
  --title "Your MR title for main" \
  --description "Description of changes"
```

---

#### Quick Shortcut (Using `--fill`)
If you want `glab` to automatically take the title and description from your commit messages:

```bash
# 1. Switch to the develop branch and create MR to develop
git checkout <your-develop-branch>
glab mr create --target-branch develop --fill --yes

# 2. Switch to the main branch and create MR to main
git checkout <your-main-branch>
glab mr create --target-branch main --fill --yes
```

---

#### Useful Flags:
- `--remove-source-branch`: Automatically deletes the branch once merged.
- `--squash-before-merge`: Squashes commits upon merge.
- `--assignee @username`: Assigns the MR to someone.
- `--draft`: Marks the MR as a draft / WIP.

*(Note: If you literally meant merging the two feature branches into one another, you can simply set `--source-branch <branch-1> --target-branch <branch-2>` using the same command).*

---

## 🐙 GitHub CLI (`gh`) & Pull Requests

The container also includes the official **GitHub CLI (`gh`)** pre-installed for interacting with GitHub repositories.

### 1. Log in to `gh`
Run the interactive login command:
```bash
gh auth login
```
Follow the interactive prompts (select GitHub.com, HTTPS, authenticate via browser or paste a personal access token).

Alternatively, set your token directly via environment variable in your terminal session or `~/.bashrc`:
```bash
export GITHUB_TOKEN="<YOUR_GITHUB_PAT>"
gh auth status
```

### 2. Creating Pull Requests with `gh`
```bash
# Create a pull request targeting develop or main
gh pr create --base develop --fill

# Or interactive PR creation with prompt for title & body
gh pr create
```

---

## ⚙️ Core Helper Scripts (`development/scripts/lib/`)

Under the hood, both `installer.sh` and direct bench tasks rely on focused helper scripts in `development/scripts/lib/`:

### 1. `get-apps.sh` (App Retrieval & Registration)
- **Config input**: Accepts `apps.json` or a filtered temporary JSON.
- **Public Frappe Apps**: If `url` is empty, fetches via `bench get-app <name> --branch <branch> --resolve-deps`.
- **Private & Git Apps**: Clones the repo into `frappe-bench/apps/<folder_name>`, installs it into the bench environment with `uv pip install --editable` (or pip fallback), installs `requirements.txt`, and registers the folder in `sites/apps.txt`.
- **Refspec Expansion**: Automatically expands the Git fetch refspec to `+refs/heads/*:refs/remotes/origin/*` and fetches all remote tags/branches so future checkouts succeed offline.

### 2. `setup-site.sh` (Site Deployment & Orchestration)
- **Database Initialization**: Creates the site in MariaDB/PostgreSQL using `bench new-site`.
- **Core Stack**: Installs `frappe`, `erpnext`, and `hrms`.
- **Automated Headless Wizard**:
  Executes `frappe.desk.page.setup_wizard.setup_wizard.setup_complete` headlessly with configuration args from the site JSON's `setup` block (language, country, currency, timezone, admin user).
  Drains demo background jobs using `bench worker --queue default --burst`.
- **Custom Apps**: Iterates through the remaining apps in declared order, executes `bench --site <site> install-app <app>`, runs `bench migrate`, updates Node requirements (`bench setup requirements --node`), and builds assets (`bench build --app`).
- **Rollback Guard**: Prompts to rollback and uninstall an app if its installation fails during the run.

---

## 🏗️ Architecture & Directory Structure

```text
ultio-project/
├── .devcontainer/
│   ├── Dockerfile                  # Extended Frappe Bench image (glab, gh, pre-commit, git optimizations)
│   ├── devcontainer.json           # Dev container definition, lifecycle scripts & AI/dev extensions
│   ├── docker-compose.yml          # MariaDB, Redis (cache & queue), and Frappe bench custom build
│   └── scripts/
│       ├── post-create.sh          # Lifecycle script: verifies pre-commit, configures Git SSH signing
│       └── post-start.sh           # Lifecycle script: initializes ssh-agent for passphrase keys
├── development/
│   ├── installer.sh                # Main interactive setup entrypoint
│   ├── AGENTS.md                   # Engineering standards, workflow & pair-programming rules
│   ├── scripts/
│   │   ├── apps/
│   │   │   └── apps.json           # Master registry of upstream & custom apps with Git URLs
│   │   ├── lib/
│   │   │   ├── common.sh           # Shared utilities (colored logging, JSON parser, site commands)
│   │   │   ├── prompts.sh          # Interactive terminal input prompts & validation
│   │   │   ├── apps.sh             # App selection menu logic & get-apps invocation
│   │   │   ├── sites.sh            # Site mode selection menu logic & setup-site invocation
│   │   │   ├── bench.sh            # Bench initialization and process startup helpers
│   │   │   ├── get-apps.sh         # App cloning, dependency install (uv), refspec expansion
│   │   │   └── setup-site.sh       # Site database creation, headless wizard, app installation
│   │   ├── sites/                  # Individual site definitions (*.json)
│   │   └── switch-site-app-refs.sh # Standalone tool to checkout Git branches per site profile
│   ├── frappe-bench/               # Active Frappe bench workspace (Git ignored)
│   └── backups/                    # Local site database backups and dumps (Git ignored)
└── README.md                       # Workspace guide & technical reference
```

---

## 📋 Included Site Profiles (`scripts/sites/`)

Each JSON file in `development/scripts/sites/` defines a site name, setup wizard parameters, and an ordered list of apps and their required branches/tags.

| Config File | Site Name | Included Custom Applications |
|---|---|---|
| `aljar.json` | `aljar.localhost` | `erp_fabrica`, `hr_fabrica`, `fabrica_accounting`, `crm_integration`, `aljar_system`, `learning_center` |
| `alqamzi.json` | `alqamzi.localhost` | `erp_fabrica`, `hr_fabrica`, `fabrica_accounting`, `alqamzi_system`, `fabrica_factoring`, `fabrica_leasing`, `child_table_pagination`, `learning_center` |
| `biography.json` | `biography.localhost` | `erp_fabrica`, `fabrica_accounting`, `crm_integration`, `biography_erp`, `learning_center` |
| `coverage.json` | `coverage.localhost` | `persona`, `erp_fabrica`, `fabrica_pos_awesome`, `coverage_erp`, `learning_center` |
| `egyproperty.json` | `egyproperty.localhost` | `alerts`, `zk_bio_device`, `sip_calls`, `insights`, `text_to_filters`, `egyproperty`, `realestate_crm`, `persona` |
| `el_masria.json` | `el_masria.localhost` | `erp_fabrica`, `hr_fabrica`, `bio_time_software`, `salary_tax_eg`, `elmasria_erp`, `learning_center` |
| `fabrica.json` | `fabrica.localhost` | `erp_fabrica`, `fabrica_system`, `print_designer`, `hr_fabrica`, `fabrica_pm`, `learning_center` |
| `imarrae.json` | `imarrae.localhost` | `erp_fabrica`, `salary_tax_eg`, `zk_bio_device`, `crm_integration`, `imarrae_system`, `learning_center` |
| `kunouz.json` | `kunouz.localhost` | `erp_fabrica`, `hr_fabrica`, `bio_time_software`, `kunouz_erp`, `learning_center` |
| `saoud.json` | `saoud.localhost` | `erp_fabrica`, `hr_fabrica`, `crm_integration`, `saoudurban_erp`, `learning_center` |
| `standard_fabrica_erp.json` | `standard_fabrica_erp.localhost` | Standard Fabrica baseline (`fabrica_accounting`, `fabrica_construction`, `crm_integration`) |
| `tutorial.json` | `tutorial.localhost` | Lightweight learning sandbox (`airplane_mode`, `commit`) |
| `uc.json` | `uc.localhost` | `erp_fabrica`, `hr_fabrica`, `bio_time_software`, `ucdevelopement_system`, `learning_center` |
| `vie_communities.json` | `vie_communities.localhost` | `erp_fabrica`, `hr_fabrica`, `vie_system`, `learning_center` |

*Standard sites conclude with the maintenance stack:* `handover` (`develop`) → `wiki` (`v2.0.1`) → `documentation_upkeep_client` (`develop`) → `commit` (`main`) → `fabrica_commit` (`main`).

---

## 🔌 Container Infrastructure & Stack

Configured through `.devcontainer/docker-compose.yml`:

| Service | Image | Internal Host | Ports | Credentials / Configuration |
|---|---|---|---|---|
| **Frappe Bench** | Custom (`.devcontainer/Dockerfile` based on `frappe/bench:v5.27.0`) | `frappe` | `8000-8005`, `9000-9005` | Pre-configured with `glab`, `gh`, `pre-commit`, Git HTTP tuning, SSH signing, and AI extensions |
| **MariaDB** | `mariadb:10.6` | `mariadb` | `3306` | Root user: `root`, Password: `123` |
| **Redis Cache** | `redis:alpine` | `redis-cache` | `6379` | `redis://redis-cache:6379` |
| **Redis Queue** | `redis:alpine` | `redis-queue` | `6379` | `redis://redis-queue:6379` (Worker queues & Socket.IO) |

### Pre-configured VS Code Extensions
The Dev Container environment automatically installs the following developer tools and AI companions:
- **Core Python, Web & Markdown**: `ms-python.python`, `ms-vscode.live-server`, `grapecity.gc-excelviewer`, `bierner.markdown-mermaid` (Mermaid diagram preview)
- **Database**: `mtxr.sqltools`, `mtxr.sqltools-driver-mysql`
- **Git & Productivity**: `visualstudioexptteam.vscodeintellicode`, `eamodio.gitlens`
- **AI Coding Agents**:
  - `Google.google-antigravity` (Google Antigravity)
  - `openai.chatgpt` (Codex – OpenAI's coding agent)
  - `anthropic.claude-code` (Claude Code)

---

## 🐞 VS Code Debugging Configurations

The workspace includes pre-configured debug profiles in `.vscode/launch.json`:

- **`Bench Web`**: Launches and debugs the Frappe web process with `debugpy` attached.
- **`Bench Default Worker`**: Debugs background job executions dispatched to the default queue.
- **`Bench Short Worker` / `Bench Long Worker`**: Debugs short/long burst queue execution.
- **`Honcho + Web debug`**: Compound debug task running Honcho process orchestration alongside the web server debugger.

To start debugging:
1. Open the Debug View (`Ctrl + Shift + D`).
2. Select **`Bench Web`** from the configuration dropdown.
3. Press **`F5`** to launch with breakpoints enabled.

---

## ❓ Troubleshooting

### 1. Permission Denied (publickey) on Private Repositories
- **Symptom**: `git clone git@git.fabrica-dev.com:...` fails.
- **Solution**: Confirm SSH access on your host with `ssh -T git@git.fabrica-dev.com`. Make sure your key is in `~/.ssh/` before the Dev Container is built, as the container mounts this directory into `/home/frappe/.ssh`.

### 2. Browser Displays "Site Not Found"
- **Symptom**: Opening `http://<site-name>:8000` shows Frappe's 404 page.
- **Solution**: Run `bench use <site-name>` inside `frappe-bench`, restart `bench start`, and reload.

### 3. Switch Refs Fails with "Uncommitted Changes"
- **Symptom**: `switch-site-app-refs.sh` halts reporting dirty working trees.
- **Solution**: Run `git status` inside the reported app folder under `development/frappe-bench/apps/<app>`, then commit or stash changes before re-running the switcher.

### 4. Node / Asset Compilation Out of Sync
- **Symptom**: Desk UI components or custom app styles fail to render.
- **Solution**: Run:
  ```bash
  bench setup requirements --node
  bench build
  bench --site <site-name> clear-cache
  ```

---

## 📖 Official References

- [Frappe Framework v15 Docs](https://frappeframework.com/docs/v15/user/en/)
- [ERPNext Documentation](https://docs.erpnext.com/)
- [Frappe Bench CLI Reference](https://frappeframework.com/docs/v15/user/en/bench/frappe-commands)
- [VS Code Dev Containers Documentation](https://code.visualstudio.com/docs/devcontainers/containers)
