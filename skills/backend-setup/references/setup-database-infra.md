
---
name: setup-database-infra
description: Provision a Neon PostgreSQL database for the project and configure the connection string in the server .env file
---

# Setup Database Infrastructure

When asked to set up or provision the database, use this skill to create a Neon PostgreSQL database and configure the backend to connect to it.

## Prerequisites

- The Neon CLI must be available (`neonctl`). If not installed, install it globally first:

```bash
npm install -g neonctl
```

Then verify with `neonctl --version`. If the user is not authenticated, run `neonctl auth` to open the browser login flow.

## Steps

### 1. Determine the project name

The database name should match the project name. Derive it from the root `package.json` `name` field or the git repo directory name, stripping suffixes like `-server` or `-backend`.

### 2. Check for existing Neon projects

Before creating anything, run:

```bash
neonctl projects list --output json
```

Check if a project named after the project already exists. If it does, skip creation and use the existing project.

### 3. Create the Neon project

If no matching project exists, run:

```bash
neonctl projects create --name <project_name> --region-id aws-us-east-2 --output json
```

Pick the closest region to the user or default to `aws-us-east-2`. Note the returned `id` (project ID).

### 4. Get the connection string

Run:

```bash
neonctl connection-string --project-id <project_id> --pooled --output json
```

This returns the pooled connection string for the default database (`neondb`).

### 5. Write the connection string to `.env`

1. Read the server `.env` file at `server/.env`
2. If a `DATABASE_URL` line already exists, replace its value with the new connection string
3. If no `DATABASE_URL` line exists, append it
4. The format must be: `DATABASE_URL="<connection_string>"`

### 6. Verify the connection

After updating `.env`, confirm the database is reachable by running:

```bash
neonctl connection-string --project-id <project_id> | xargs -I {} psql {} -c "SELECT 1"
```

Or alternatively, use the server's own database connection by running the app or a migration check.

## Notes

- Never commit the `.env` file — ensure it is listed in `.gitignore`
- All `neonctl` commands support `--output json` for structured output — prefer this when parsing results
