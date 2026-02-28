# Pantri

A clean, flat Swift iOS app — everything lives in a **single `Pantri/` folder** with zero deep nesting. Groups are expressed through file-name prefixes, not subfolders.

---

## Flat Folder Structure

```
Pantri/
├── PantriApp.swift                     # @main entry point; bootstraps AppContainer and root view
├── ContentView.swift                   # Root SwiftUI view; hosts top-level navigation stack
├── AppContainer.swift                  # Dependency injection container; owns all shared services
├── AppRouter.swift                     # Navigation coordinator; manages NavigationPath / deep links
│
├── Model_Item.swift                    # Domain model: pantry item (id, name, quantity, expiry)
├── Model_User.swift                    # Domain model: authenticated user (id, name, email)
├── Model_Category.swift                # Domain model: item category (id, name, icon)
│
├── View_ItemListView.swift             # SwiftUI view: full pantry item list screen
├── View_ItemDetailView.swift           # SwiftUI view: single item detail / edit screen
├── View_AddItemView.swift              # SwiftUI view: form for adding a new pantry item
├── View_SettingsView.swift             # SwiftUI view: user settings and account screen
│
├── ViewModel_ItemList.swift            # @Observable ViewModel: loads, filters, sorts items
├── ViewModel_ItemDetail.swift          # @Observable ViewModel: editing and saving one item
├── ViewModel_AddItem.swift             # @Observable ViewModel: validates the add-item form
│
├── Repo_ItemRepository.swift           # Protocol: injectable CRUD interface for pantry items
├── Repo_ItemRepositoryImpl.swift       # Concrete implementation: calls NetworkClient, caches locally
├── Repo_UserRepository.swift           # Protocol: injectable read/update interface for user profile
│
├── UseCase_FetchItems.swift            # Use case: fetches the current user's pantry items
├── UseCase_AddItem.swift               # Use case: validates and persists a new pantry item
├── UseCase_UpdateItem.swift            # Use case: updates an existing item and syncs with backend
├── UseCase_DeleteItem.swift            # Use case: removes an item and syncs with backend
│
├── Service_NetworkClient.swift         # Generic async/await HTTP client; REST/GraphQL requests
├── Service_APIEndpoints.swift          # All endpoint URL definitions and request builders
├── Service_AuthService.swift           # Auth token management, refresh flow, session state
│
├── Mapper_ItemMapper.swift             # Maps Item ↔ ItemDTO (API request/response)
├── Mapper_UserMapper.swift             # Maps User ↔ UserDTO (API request/response)
│
├── Error_AppError.swift                # App-wide error enum: network, auth, validation, unknown
│
├── Extension_View+Modifiers.swift      # SwiftUI View helpers: loading overlay, error alert
├── Extension_String+Validation.swift   # String utilities: trimmed isEmpty, email validation
├── Extension_Date+Formatting.swift     # Date helpers: expiry strings, relative display
│
└── Assets.xcassets/                    # Asset catalog: app icon, accent color, image assets
```

---

## Design Principles

| Principle | How it's applied |
|-----------|-----------------|
| **Flat** | One folder, no sub-folders. |
| **Prefix grouping** | `Model_`, `View_`, `ViewModel_`, `Repo_`, `UseCase_`, `Service_`, `Mapper_`, `Error_`, `Extension_` |
| **Dependency Injection** | `AppContainer` owns every service; injected via SwiftUI `.environment` or constructor. |
| **Clean Architecture** | Views → ViewModels → Use Cases → Repositories → NetworkClient. |
| **Backend-ready** | `Service_NetworkClient` + `Service_APIEndpoints` cover REST; swap for GraphQL with minimal changes. |
| **Testable** | Every `Repo_*` and `Service_*` is protocol-backed — mock easily in unit tests. |
| **Modern Swift** | `@Observable`, `async/await`, `Sendable` — targets iOS 17+. |

---

## How to Push Changes to the Main Branch

### Option 1: Merge via Pull Request (Recommended)

1. **Open the Pull Request** on GitHub (e.g., this PR).
2. Once reviewed and approved, click **"Merge pull request"** on GitHub.
3. Click **"Confirm merge"**.
4. Your changes will now be in `main`.

### Option 2: Merge from the Command Line

```bash
git checkout main
git pull origin main
git merge copilot/create-flat-folder-structure
git push origin main
```

### Option 3: Using GitHub CLI

```bash
gh pr merge <PR-number> --merge
```
