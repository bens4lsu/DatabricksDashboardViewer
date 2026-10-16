# Databricks AI/BI Dashboard Embedding with Swift Vapor

A production-ready Swift Vapor server-side framework that handles OAuth 2.0 Machine-to-Machine (M2M) authentication using Databricks Service Principal credentials, securely downscopes tokens for external viewers, and serves an interactive web page embedding the Databricks dashboard in an `iframe` via the official `@databricks/aibi-client` SDK.

---

## Architecture & Authentication Flow

Embedding Databricks dashboards for external viewers (who do not have Databricks workspace logins) requires a 3-step OAuth handshake:

1. **Broad M2M Token Exchange (`POST /oidc/v1/token`)**:
   - The Vapor server authenticates using the Service Principal's Client ID and OAuth Secret via HTTP Basic Auth (`Authorization: Basic base64(client_id:client_secret)`).
   - Databricks returns an initial broad OIDC token scoped to `all-apis`.
2. **Lakeview Token Info Query (`GET /api/2.0/lakeview/dashboards/<dashboard_id>/published/tokeninfo`)**:
   - The server requests metadata and authorization details for the specific dashboard, passing an `external_viewer_id` (for non-PII audit logging) and `external_value` (for row-level data filtering in SQL datasets via `__aibi_external_value`).
3. **Downscoped User Token Generation (`POST /oidc/v1/token`)**:
   - The server issues a second OIDC call providing the extracted `authorization_details`.
   - Databricks issues a tightly-scoped access token valid for 1 hour that permits access *only* to this specific dashboard and viewer context.
4. **Client-Side iFrame Embedding**:
   - The Vapor server renders an HTML web page containing a container element and imports `@databricks/aibi-client`.
   - The SDK spins up an `<iframe>` pointing to the Databricks embed route, injects the scoped token securely, and initializes interactive bi-directional filters.

---

## Databricks Workspace Prerequisites

Before launching the Vapor application, complete these administrative steps in your Databricks Workspace:

1. **Create a Service Principal**:
   - Go to **Settings > Identity and access > Service principals > Add service principal**.
   - Note the **Application (Client) ID**.
   - Ensure **Databricks SQL access** and **Workspace access** entitlements are checked.
2. **Generate an OAuth Secret**:
   - Open the Service Principal details, navigate to the **Secrets** tab, and click **Generate secret**.
   - Copy the secret immediately; this is your `DATABRICKS_CLIENT_SECRET`.
3. **Grant Dashboard & Data Permissions**:
   - Open your published AI/BI Dashboard, click **Share**, search for your Service Principal, and assign **CAN RUN** permission.
   - If using individual data permissions, grant the Service Principal `SELECT` access on the underlying Unity Catalog tables/views.
4. **Configure Approved Domains (MANDATORY for iFrames)**:
   - Go to **Settings > Security > Manage dashboard and Genie embedding**.
   - Add your application's domain (e.g., `http://localhost:8080` for local dev or `https://analytics.yourcompany.com` for production) to the **Approved domains** list. *Failure to do this will result in a blank iframe due to cross-origin frame protection.*

---

## Project Structure

```text
├── Package.swift                    # Swift Package Manager manifest
├── .env.example                     # Environment variable template
├── Sources/
│   └── App/
│       └── DatabricksVaporEmbed.swift  # Complete Vapor backend implementation
└── Resources/
    └── Views/
        └── dashboard.leaf           # Optional Leaf template for custom UI
```

---

## Quickstart Guide

### 1. Configure Environment

Copy `.env.example` to `.env` and fill in your Databricks credentials:

```bash
cp .env.example .env
```

Set the values:
- `DATABRICKS_INSTANCE_URL`: e.g. `https://dbc-12345678-abcd.cloud.databricks.com`
- `DATABRICKS_WORKSPACE_ID`: Your numeric workspace ID (found in the workspace URL `?o=...`)
- `DATABRICKS_DASHBOARD_ID`: The UUID of your published AI/BI dashboard
- `DATABRICKS_CLIENT_ID`: Your Service Principal Application ID
- `DATABRICKS_CLIENT_SECRET`: Your Service Principal OAuth Secret

### 2. Build and Run

With Swift 5.9+ installed:

```bash
# Resolve dependencies
swift package resolve

# Run the Vapor application
swift run App
```

By default, the server will start on `http://127.0.0.1:8080`.

### 3. Access the Embedded Dashboard

Open your browser to:
- **Default View**: `http://127.0.0.1:8080/`
- **User-Scoped View**: `http://127.0.0.1:8080/?viewerId=user_42&externalValue=EMEA`
- **JSON Scoped Token API**: `http://127.0.0.1:8080/api/token?viewerId=user_42&externalValue=EMEA`
