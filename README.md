# Pantri

## Quick Start

```bash
bash setup.sh
```

This creates a virtual environment, installs dependencies, writes a default `.env`
(SQLite for local dev), and starts the FastAPI backend on **http://127.0.0.1:3000**.

Then open `Hack For Humanity/Hack For Humanity.xcodeproj` in Xcode and run the iOS
app — it already points at `http://127.0.0.1:3000`.

### Manual Backend Setup

```bash
cd src/python
python3 -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

Create a `.env` file in `src/python/` (only if you want PostgreSQL):

```
POSTGRES_PASSWORD=""
POSTGRES_USER=""
POSTGRES_HOST="localhost"
POSTGRES_DB="pantri"
```

Start the server:

```bash
python main.py   # serves on http://127.0.0.1:3000
```
To get your changes into the `main` branch, follow these steps:

### Option 1: Merge via Pull Request (Recommended)

1. **Open the Pull Request** on GitHub (e.g., this PR).
2. Once reviewed and approved, click **"Merge pull request"** on GitHub.
3. Click **"Confirm merge"**.
4. Your changes will now be in `main`.

### Option 2: Merge from the Command Line

If you have write access to the repository, you can merge locally:

```bash
# Switch to the main branch
git checkout main

# Pull the latest changes
git pull origin main

# Merge the feature branch
git merge copilot/push-changes-to-main-branch

# Push the merged result to GitHub
git push origin main
```

### Option 3: Using GitHub CLI

```bash
# Merge the open PR (replace <PR-number> with the actual PR number)
gh pr merge <PR-number> --merge



```
