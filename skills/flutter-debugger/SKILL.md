---
name: debugger
description: Help debug code
---

# Debugging Workflow

All debug logging goes through a local HTTP instrumentation server. Never use console/stdout logging (`print`, `console.log`, `logger.*`, `puts`, `fmt.Println`, or any language equivalent). Send structured logs via HTTP POST so they can be viewed in real time in the terminal regardless of platform.

## Constraints

- NEVER use any form of console/stdout logging. No `print()`, `console.log()`, `debugPrint()`, `logger.*`, or any language-specific equivalent. There are no exceptions.
- ALL logging MUST go through an HTTP POST to the local instrumentation server at `127.0.0.1:8389/log`.
- The instrumentation server MUST be running before any debugging begins. If it is not running, start it first.
- Keep debug instrumentation minimal and targeted — only instrument code paths relevant to the current hypothesis.
- NEVER leave debug instrumentation in the code after the bug is fixed.
- ALWAYS kill the instrumentation server process when the debugging session is complete.

## Steps

### 1. Analyze the bug and form hypotheses

Before touching any code:
- Read the relevant source files to understand the current behavior.
- Form hypotheses about what could be causing the issue. Rank them by likelihood.
- Present the hypotheses to the user and explain what logs would confirm or reject each one.

### 2. Instrument code with debug logging

Add targeted calls to the debug logger at key points to test your hypotheses. Instrument whatever code paths are relevant to the issue — state, networking, UI, navigation, permissions, anything.

### 3. Start the instrumentation server

Start `debug_log_server.dart` before any debugging begins:

```bash
dart run scripts/debug_log_server.dart
```

### 4. Tell the user the reproduction steps

Stop and clearly describe the exact steps needed to reproduce the issue. Format as a numbered list. Wait for the user to confirm they can reproduce the issue.

Do NOT proceed until the user confirms.

### 5. Analyze logs and iterate

Once logs come in:
- Review them against each hypothesis.
- Explicitly state which hypotheses are confirmed, rejected, or need more data.
- If a hypothesis is rejected, form a new one based on what the logs revealed.
- Update instrumentation as needed — add new log points, remove unhelpful ones.
- Repeat steps 4-5 until the root cause is identified.

### 6. Fix the bug

Once the root cause is confirmed:
- Propose the fix to the user before implementing.
- Implement the minimal fix needed.
- Keep debug instrumentation in place during this step so the user can verify the fix works.

### 7. Clean up

After the user confirms the fix works:
- Remove ALL debug logger calls that were added.
- Remove any imports of the debug logger.
- Verify no debug instrumentation remains with a grep.
- Kill the instrumentation server process (`kill $(lsof -t -i:8389)`).
