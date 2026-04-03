
---
name: setup-firebase-infra
description: Set up Firebase project infrastructure including Auth, service account, and backend integration
---

# Setup Firebase Infrastructure

When asked to set up Firebase infrastructure, use this guide to create or configure a Firebase project with Authentication enabled and integrate it into the backend.

## Prerequisites

- The **Google Cloud CLI** (`gcloud`) must be available. If not installed, install it first:

```bash
# macOS (Homebrew)
brew install --cask google-cloud-sdk
```

Then verify with `gcloud --version`. If the user is not authenticated, run `gcloud auth login` to open the browser login flow.

- The **Firebase CLI** (`firebase`) must be available. If not installed, install it globally:

```bash
npm install -g firebase-tools
```

Then verify with `firebase --version`. If the user is not authenticated, run `firebase login` to open the browser login flow.

## Steps

### 1. Check for existing Firebase projects

Before creating anything, check if the user already has a Firebase project:

```bash
firebase projects:list
```

If a project matching the repo/app name already exists, use it. If a `FIREBASE_SERVICE_ACCOUNT_PATH` already exists in the `.env` file and the file it points to exists, the project is already provisioned — skip to Step 4.

### 2. Create a Firebase project

If no matching project exists, create one:

```bash
firebase projects:create <project-id> --display-name "<Project Name>"
```

- Derive the project ID from the repo/folder name (lowercase, hyphens, no underscores)
- The display name can be the human-readable version of the project name

### 3. Generate a service account key

A service account key is required for `firebase-admin` to verify tokens server-side. Always use `gcloud` to create the key file.

1. Check if a `FIREBASE_SERVICE_ACCOUNT_PATH` already exists in the `.env` file and the file it points to exists — if it does, skip generation
2. If not, find the Firebase Admin SDK service account email:

```bash
gcloud iam service-accounts list --project=<project-id> --format="value(email)" --filter="displayName:firebase-adminsdk"
```

3. Create the key file using `gcloud` and save it to the **server project root** (the directory containing `package.json`):

```bash
gcloud iam service-accounts keys create firebase-service-account.json \
  --iam-account <service-account-email> \
  --project=<project-id>
```

Do NOT use the Firebase Console to generate keys — always use `gcloud`. The output path in the command above is relative to the current working directory — make sure you run this from the server project root, or use an absolute path.

### 4. Configure environment variables

1. Read the server `.env` file
2. If `FIREBASE_SERVICE_ACCOUNT_PATH` does not exist, add it with the **relative path from the server project root** to wherever the key file was saved:

```
FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json
```

3. The path must match the actual location of the key file — do not hardcode a path without verifying the file exists there
4. Ensure the service account JSON file is listed in `.gitignore` — **never commit service account keys**

### 5. Initialize Firebase Admin in the backend

Create or verify the Firebase Admin singleton at `src/services/firebase.ts`:

```typescript
import path from 'path';
import admin from 'firebase-admin';
import { env } from '../env_config';

// Use path.resolve() so the relative path in FIREBASE_SERVICE_ACCOUNT_PATH
// resolves from the project root (cwd), not from this source file's directory.
const serviceAccount = require(path.resolve(env.FIREBASE_SERVICE_ACCOUNT_PATH));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

export const firebaseAuth = admin.auth();
export default admin;
```

### 6. Set up the auth middleware

Create or verify the auth middleware at `src/auth.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { firebaseAuth } from './services/firebase';
import { UnauthorizedException } from './error_handling';

export const authenticate = async (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    return next(new UnauthorizedException('Missing or invalid authorization header'));
  }

  const token = authHeader.split('Bearer ')[1];

  try {
    const decodedToken = await firebaseAuth.verifyIdToken(token);
    req.user = decodedToken;
    next();
  } catch (error) {
    next(new UnauthorizedException('Invalid or expired token'));
  }
};
```

Ensure the Express `Request` type is extended to include `user`:

```typescript
// src/types/express.d.ts
import { DecodedIdToken } from 'firebase-admin/auth';

declare global {
  namespace Express {
    interface Request {
      user?: DecodedIdToken;
    }
  }
}
```

### 7. Verify the setup

After everything is configured:

1. Confirm `firebase-admin` is installed: check `package.json` for `firebase-admin`
2. Verify the service account file is valid JSON and contains the required fields (`project_id`, `private_key`, `client_email`)
3. Verify the project compiles with `tsc --noEmit`

### 8. Enable auth providers and redirect the user

This is the **final step** — do NOT run this until all previous steps are complete (service account created, backend scaffolded, project compiles).

#### 8a. Deploy anonymous auth via the Firebase CLI

Write a temporary `firebase.json`, deploy, then clean up:

```bash
# Create temporary firebase.json
echo '{"auth":{"providers":{"anonymous":true}}}' > firebase.json

# Deploy auth providers (creates .firebaserc as a side effect)
firebase deploy --only auth --project=<project-id>

# Clean up — these files are not needed after deployment
rm -f firebase.json .firebaserc
```

This enables anonymous sign-in without requiring billing or Identity Platform.

#### 8b. Redirect the user to add Google and Apple sign-in

Google and Apple sign-in require OAuth credentials that cannot be set up via the CLI. Open the user's browser to the Firebase Authentication sign-in providers page:

```bash
open "https://console.firebase.google.com/project/<project-id>/authentication/providers"
```

Tell the user to enable Google and Apple sign-in from that page. Google typically auto-generates OAuth credentials when enabled. Apple requires an Apple Developer account with a Service ID configured for Sign in with Apple.

## Notes

- Never commit the service account JSON file — ensure it is in `.gitignore`
- Never commit `.env` files
- The service account key gives full admin access to the Firebase project — treat it as a secret
- For production deployments, prefer using environment variables or secret managers over file-based service account keys
- If the project uses Firebase beyond Auth (e.g., Firestore, Storage), extend the `src/services/firebase.ts` singleton to export those clients as well
