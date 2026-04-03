# wulo

*wulo* means ["helpful" in Yoruba](https://www.wordhippo.com/what-is/the-meaning-of/yoruba-word-2a9a33072ff1e0847f3f823f29b88eaa965a96b0.html). This is a collection of helpful scripts and skill definitions I use to streamline my development workflow.

## Skills

### [debugger](skills/debugger)

A structured debugging workflow that routes all debug logging through a local HTTP instrumentation server instead of console/stdout. Includes a Dart-based log server (`debug_log_server.dart`) that receives structured JSON logs over HTTP and prints them to the terminal with color formatting. Designed to keep debug output centralized and easy to follow regardless of platform.

### [backend-stack](skills/backend-stack)

A scaffold definition for new Node.js backends. Defines a full tech stack (Express, TypeScript, PostgreSQL, Drizzle ORM, Firebase Auth, Zod) and a feature-module project structure with conventions for error handling, request validation, and database access.
