---
name: backend-setup
description: Scaffold a new Node.js/Express/TypeScript backend with PostgreSQL, Drizzle ORM, Firebase Auth, and feature-module architecture
---

# Backend Setup

When asked to set up or scaffold a new backend, follow the **Scaffolding Steps** below in order. Every step is mandatory — do not skip any.

## Scaffolding Steps

Execute these steps sequentially when scaffolding a new backend project:

1. **Create the project directory** and initialize with `pnpm init`.
2. **Install all dependencies** (see Tech Stack below).
3. **Scaffold the source files** following the Project Structure and Architecture Rules below.
4. **Provision the Neon database** — this is NOT optional. You MUST use the Neon CLI (`neonctl`) — do NOT fall back to MCP tools:
   - **Install neonctl if missing:** Run `which neonctl` first. If the command is not found, install it with `npm install -g neonctl` and verify with `neonctl --version`
   - **Authenticate if needed:** Run `neonctl projects list --output json`. If authentication fails, run `neonctl auth` to open the browser login flow and wait for the user to complete it before continuing
   - Check for existing projects: `neonctl projects list --output json`
   - If no matching project exists, create one: `neonctl projects create --name <project_name> --region-id aws-us-east-2 --output json` (derive the name from the repo/folder name, stripping `-server`/`-backend` suffixes)
   - Get the pooled connection string: `neonctl connection-string --project-id <project_id> --pooled --output json`
   - Write `DATABASE_URL` to the project's `.env` file
   - Verify the connection is live
   - See `references/setup-database-infra.md` for full details
5. **Generate and apply initial migrations** if feature modules were requested.
6. **Verify the project compiles** with `tsc --noEmit`.

## Tech Stack

## Tech Stack

- **Runtime:** Node.js + TypeScript
- **Framework:** Express.js
- **Database:** PostgreSQL
- **ORM:** Drizzle ORM (`drizzle-orm` + `drizzle-kit` for migrations)
- **Authentication:** Firebase Auth (Bearer token verification via `firebase-admin`)
- **Validation:** Zod schemas with a reusable `validate()` middleware
- **Environment config:** `dotenv` + `envalid` for strict env var validation
- **Logging:** Winston + `winston-console-format` for colorized dev output
- **Build:** `tsc` for production, `tsx watch` for dev
- **Package manager:** pnpm

## Project Structure

```
src/
├── app/                           # Feature modules (one folder per feature)
│   └── <feature>/
│       ├── <feature>.schema.ts    # Drizzle table schema
│       ├── <feature>.controller.ts # Route handlers
│       ├── <feature>.service.ts   # Business logic
│       ├── <feature>.route.ts     # Express router
│       └── <feature>.validation.ts # Zod schemas
├── database/
│   ├── index.ts                   # Drizzle client instance (db)
│   ├── schema.ts                  # Re-exports all table schemas
│   └── migrations/                # Drizzle Kit generated migrations
├── services/                      # Third-party service clients (singletons)
├── middlewares/                    # Express middlewares
├── auth.ts                        # Token verification middleware
├── error_handling.ts              # Global error handler
├── logger.ts                      # Winston logger setup
├── env_config.ts                  # envalid environment validation
├── request_validation.ts          # Zod validation middleware
├── api.routes.ts                  # Route aggregation
└── app.ts                         # Express app entry point (runs migrations, then listens)
```

## Architecture Rules

### Feature Modules
Each feature lives in `src/app/<feature>/` with its own entity, controller, service, route, and optional validation file. Keep features self-contained.

### Middleware Stack (applied in order)
1. CORS
2. JSON body parser
3. Request logger
4. Auth middleware on protected routes
5. Global error handler (last)

### Error Handling
- Create a base `HttpException` class extending `Error` with a `statusCode` and optional `data` property
- Create NestJS-style subclasses for each common HTTP error status:
  - `BadRequestException` (400)
  - `UnauthorizedException` (401)
  - `ForbiddenException` (403)
  - `NotFoundException` (404)
  - `ConflictException` (409)
  - `GoneException` (410)
  - `InternalServerErrorException` (500)
- Each subclass accepts `(message?: string, data?: any)` with a sensible default message
- For non-standard status codes, use `HttpException` directly: `new HttpException('msg', 208)`
- Global error middleware catches `HttpException` and returns a safe response
- **Production safety:** Never expose `data` on 500 errors in production — only include `data` for client errors (4xx) where the controller explicitly provided it (e.g. validation errors)
- Unhandled errors (non-`HttpException`) always return a generic 500 with no details — log the real error server-side

```typescript
// src/error_handling.ts
import { Request, Response, NextFunction } from 'express';
import { logger } from './logger';

const isProduction = process.env.NODE_ENV === 'production';

export class HttpException extends Error {
  readonly statusCode: number;
  readonly data?: any;

  constructor(message: string, statusCode: number, data?: any) {
    super(message);
    this.name = this.constructor.name;
    this.statusCode = statusCode;
    this.data = data;
  }
}

export class BadRequestException extends HttpException {
  constructor(message = 'Bad Request', data?: any) {
    super(message, 400, data);
  }
}

export class UnauthorizedException extends HttpException {
  constructor(message = 'Unauthorized', data?: any) {
    super(message, 401, data);
  }
}

export class ForbiddenException extends HttpException {
  constructor(message = 'Forbidden', data?: any) {
    super(message, 403, data);
  }
}

export class NotFoundException extends HttpException {
  constructor(message = 'Not Found', data?: any) {
    super(message, 404, data);
  }
}

export class ConflictException extends HttpException {
  constructor(message = 'Conflict', data?: any) {
    super(message, 409, data);
  }
}

export class GoneException extends HttpException {
  constructor(message = 'Gone', data?: any) {
    super(message, 410, data);
  }
}

export class InternalServerErrorException extends HttpException {
  constructor(message = 'Internal Server Error', data?: any) {
    super(message, 500, data);
  }
}

export const globalError = (err: Error, req: Request, res: Response, next: NextFunction) => {
  if (err instanceof HttpException) {
    const isServerError = err.statusCode >= 500;

    if (isServerError) {
      logger.error(err.message, { statusCode: err.statusCode, data: err.data, stack: err.stack });
    }

    const response: { message: string; data?: any } = {
      message: isServerError && isProduction ? 'Internal Server Error' : err.message,
    };

    // Only include data for client errors (4xx), never for 5xx in production
    if (!isServerError && err.data) {
      response.data = err.data;
    } else if (isServerError && !isProduction && err.data) {
      response.data = err.data;
    }

    res.status(err.statusCode).json(response);
  } else {
    logger.error('Unhandled error', { message: err.message, stack: err.stack });
    res.status(500).json({ message: 'Internal Server Error' });
  }
};
```

### Request Validation
- Define Zod schemas per route in `<feature>.validation.ts`
- Three validation middlewares in `src/request_validation.ts`: `validateBody`, `validateQueryParams`, `validateParams`
- Each takes a `ZodObject` schema, runs `safeParse`, and calls `next(new BadRequestException(...))` on failure
- On success, `req.body` / `req.params` is replaced with the parsed data
- Errors are flattened via `z.flattenError` for consistent error shape
- Use `z.infer<typeof Schema>` to derive types from Zod schemas, then pass them as Express `Request` generics for end-to-end type safety in controllers

#### Controller Type Safety with Request Generics

Express `Request` accepts generics: `Request<Params, ResBody, ReqBody, ReqQuery>`. Use `z.infer` types in these slots so validated data is typed on the request object:

```typescript
// src/app/<feature>/<feature>.validation.ts
import z from 'zod';

export const listQuerySchema = z.object({
  status: z.string(),
  limit: z.coerce.number().optional(),
});

export type ListQuerySchema = z.infer<typeof listQuerySchema>;

export const createBodySchema = z.object({
  title: z.string(),
  description: z.string().optional(),
});

export type CreateBodySchema = z.infer<typeof createBodySchema>;
```

```typescript
// src/app/<feature>/<feature>.controller.ts
import { Request, Response } from 'express';
import { ListQuerySchema, CreateBodySchema } from './<feature>.validation';

// Query params typed in the 4th generic slot
export const list = async (
  req: Request<{}, {}, {}, ListQuerySchema>,
  res: Response,
) => {
  const { status, limit } = req.query; // fully typed
  // ...
};

// Body typed in the 3rd generic slot
export const create = async (
  req: Request<{}, {}, CreateBodySchema>,
  res: Response,
) => {
  const { title, description } = req.body; // fully typed
  // ...
};

// Route params typed in the 1st generic slot
export const getById = async (
  req: Request<{ id: string }>,
  res: Response,
) => {
  const { id } = req.params; // fully typed
  // ...
};
```

```typescript
// src/app/<feature>/<feature>.route.ts
import { Router } from 'express';
import z from 'zod';
import { validateQueryParams, validateBody, validateParams } from '../../request_validation';
import { listQuerySchema, createBodySchema } from './<feature>.validation';
import { list, create, getById } from './<feature>.controller';

const router = Router();
router.get('/', validateQueryParams(listQuerySchema), list);
router.post('/', validateBody(createBodySchema), create);
router.get('/:id', validateParams(z.object({ id: z.string() })), getById);

export default router;
```

The validation middleware ensures the data is parsed before the controller runs, so the `Request` generic types are guaranteed to be accurate at runtime.

```typescript
// src/request_validation.ts
import { NextFunction, Request, Response } from 'express';
import z, { ZodObject } from 'zod';
import { BadRequestException } from './error_handling';

const formatErrors = (error: z.ZodError) => {
  const errorIssues = error.issues.map((issue) => ({
    ...issue,
    message: issue.message.replace(/['"]/g, (match) => (match === '"' ? "'" : '"')),
  }));
  return z.flattenError({ ...error, issues: errorIssues });
};

export const validateBody =
  (schema: ZodObject) => async (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      return next(new BadRequestException('Invalid request body', formatErrors(result.error)));
    }
    req.body = result.data;
    next();
  };

export const validateQueryParams =
  (schema: ZodObject) => async (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.query);
    if (!result.success) {
      return next(new BadRequestException('Invalid request query parameters', formatErrors(result.error)));
    }
    next();
  };

export const validateParams =
  (schema: ZodObject) => async (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.params);
    if (!result.success) {
      return next(new BadRequestException('Invalid request parameters', formatErrors(result.error)));
    }
    req.params = result.data as any;
    next();
  };
```

### Database

#### Neon Database Provisioning
When scaffolding the project, **always create a Neon PostgreSQL database** as part of the setup. You MUST use the Neon CLI (`neonctl`) — do NOT use MCP tools as a fallback.

1. **Ensure neonctl is installed:** Run `which neonctl`. If not found, run `npm install -g neonctl` and verify with `neonctl --version`.
2. **Ensure the user is authenticated:** Run `neonctl projects list --output json`. If it fails with an auth error, run `neonctl auth` to open the browser login flow. Wait for the user to complete login before continuing.
3. **Check for existing projects:** `neonctl projects list --output json` — skip creation if one already matches.
4. **Create the Neon project:** `neonctl projects create --name <project_name> --region-id aws-us-east-2 --output json`. Derive the project name from the repo/folder name, stripping `-server`/`-backend` suffixes.
5. **Get the pooled connection string:** `neonctl connection-string --project-id <project_id> --pooled --output json`.
6. **Write `DATABASE_URL`** to the project's `.env` file.
7. **Verify the connection** is live before finishing.

Do NOT skip database creation or defer it to the user. Do NOT fall back to MCP tools if neonctl is missing — install it instead. The scaffolded project should be immediately runnable with a live database.

#### Drizzle ORM Setup
- One Drizzle table schema per feature in `<feature>.schema.ts` using `pgTable()`
- All schemas re-exported from `src/database/schema.ts`
- Drizzle client (`db`) and `runMigrations()` exported from `src/database/index.ts`
- `runMigrations()` uses `drizzle-orm/node-postgres/migrator` and is called before the server starts listening — migrations are applied automatically on startup, no need to run `drizzle-kit migrate` manually
- Use `drizzle-kit generate` after schema changes to create migration files
- Add a `drizzle.config.ts` at project root
- Use Drizzle relational queries (`db.query.<table>`) for reads and `db.insert()` / `db.update()` / `db.delete()` for writes

### Services
- Third-party clients (storage, email, etc.) initialized as singletons in `src/services/`
- Environment variables validated at startup before anything else

### API Conventions
- RESTful routes, JSON request/response
- Pagination via `limit` and `offset` query params
- Async controller handlers
- User context available on `req.user` after auth middleware
