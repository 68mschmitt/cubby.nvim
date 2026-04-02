# Architecture

**Thesis:** The architecture of this plugin is a strict layered system where pure computation flows inward, side effects are pushed to the edges, and every module's dependencies are visible in its function signatures.

## Principles

### 1. Core modules must be functions of their arguments, not of the world

No module in `core/` may call `require("cubby.config")`, perform file I/O, or access ambient state unless it receives those capabilities as explicit arguments.

**Rationale:** A function whose result depends only on its arguments is a function you can reason about, test, and reuse. A function that reaches into global state is a function you can only hope works.

**Violation:** A core module that internally calls `config.get()` to read settings, then makes decisions based on those settings. The caller cannot predict the function's behavior without also knowing the current config — the function signature lies about its dependencies.

### 2. Pass data down; never reach up for it

If a function needs configuration, the caller passes the relevant values. Functions do not `require("cubby.config").get()` themselves. Config is read once at the top of a command's execution path and threaded through as plain data.

**Rationale:** When six modules each independently call `config.get()`, you have six invisible couplings to a singleton. Even with defensive copies, you cannot read any function in isolation and know what it will do — its behavior depends on a value obtained from elsewhere. Pass the values explicitly so the function signature tells the truth.

**Violation:** A notification helper that deep-copies the entire config table just to check a single boolean flag, called on every command invocation.

### 3. Orchestration belongs in exactly one layer

The `note/` layer is the only place where decisions, sequencing, and callback wiring may occur. `core/` computes values. `ui/` presents choices and collects input. Neither layer makes decisions about what happens next.

**Rationale:** A callback chain is a control flow graph. If that graph is distributed across layers — UI decides to retry, core decides what to notify — you cannot see the workflow in any one place. The orchestrator's job is to be the single location where the entire flow is readable top to bottom.

**Violation:** A UI input module that contains retry logic — re-prompting the user on invalid input. That decision (whether to retry) belongs in the orchestrator. The UI module should report what happened; the orchestrator should decide what to do about it.

### 4. Separate the plan from the execution

The computation of a filename, path, and metadata must be a pure function that returns a plan (a plain data table). The execution of that plan — writing to disk, opening a buffer, sending a notification — must be a separate step.

**Rationale:** When you braid together deciding-what-to-do with doing-it, you cannot test the decision, preview the decision, or recover from a bad decision. A plan is testable without a filesystem. Execution is a boring sequence of effects.

**Violation:** A single function that computes a filename, ensures uniqueness against the filesystem, writes a file, opens a buffer, sets filetype, formats a notification, sends the notification, and updates the MRU list. That is seven concerns in one function.

### 5. State that outlives a function call must be visible in the architecture

There are exactly two kinds of persistent state: config (set once at setup, read-only thereafter) and MRU data (read/written to disk). Any new state must be explicitly named, located, and justified. No module-level mutable locals. No caches.

**Rationale:** The current clean state story — config frozen after setup, MRU persisted to disk, everything else computed — is extremely valuable and extremely easy to lose. The moment someone adds a module-level cache, you have introduced invisible coupling across time.

**Violation:** Adding `local last_used_dir = nil` at module scope to "avoid re-reading MRU." Now you have three sources of truth (config, disk, cache), the cache can be stale, and you need invalidation logic. Instead, if reads are slow, make the reads faster. Do not cache.

### 6. The dependency arrow points inward, without exception

`core/` depends on nothing outside itself. `ui/` depends only on Vim APIs and optionally `core/` utilities. `note/` may depend on anything. Nothing depends on `note/`. A grep for `require("cubby.note` in `core/` or `ui/` must return zero results. A grep for `require("cubby.config")` in `core/` must return zero results.

**Rationale:** This is not a guideline; it is the definition of layered architecture. The dependency direction determines the order of understanding: you should be able to read and verify `core/` without knowing that `note/` or `ui/` exist. The moment an inner layer depends on an outer layer, the layers cease to exist.

**Violation:** A core module that imports config to check whether a feature is enabled. That check belongs in the caller. Push the decision up. Keep the leaves simple.

### 7. Error handling is data, not control flow

Functions that can fail return `value, error_string`. Callers inspect the return. Errors are never silently swallowed, and error handling never changes the shape of the API. No function throws exceptions in a codebase that uses error returns.

**Rationale:** The `value, err` pattern is honest — it makes failure visible in the function signature. But the pattern only works if it is universal. One function that throws in a chain of functions that return errors will crash the entire plugin with an unhandled exception.

**Violation:** A function that calls `notify.warn()` on failure and returns `nil` — the caller gets no error string, only a nil. The notification is the error handling, which means the caller cannot decide how to handle the error differently.

## Anti-Patterns

### Ambient state access
A core function that calls `require("cubby.config").get()` internally instead of receiving the needed values as parameters. This hides dependencies, prevents isolated testing, and couples the function to the config module's existence.

### Distributed orchestration
Decision logic scattered across layers — retry logic in UI modules, notification decisions in core modules, feature flag checks deep in helper functions. The symptom: you cannot explain what a command does by reading one file.

### Mixed plan and execution
A single function that both computes what to do and does it. The symptom: to test "does this generate the right filename," you need a filesystem, a config, and buffer manipulation.

### Upward dependency
A core module requiring a note module, or a UI module requiring an orchestrator. The symptom: changing a note-layer function signature forces changes in core/.

### Invisible state
Module-level mutable locals (caches, flags, counters) that are not part of the documented state model. The symptom: behavior depends on call history, and tests pass in isolation but fail when run together.
