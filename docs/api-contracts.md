# API Contracts

**Thesis:** In a dynamically typed language with no access modifiers, API discipline is enforced through conventions, annotations, and one strategic runtime check at the configuration boundary — make your APIs easy to use correctly and hard to use incorrectly.

## Principles

### 1. Separate public API from internal API by convention, and mark the boundary

Every module is either public API or internal implementation. Public modules (`cubby.init`, `cubby.config`) carry a stability promise. Internal modules carry a comment: "Internal module. Not part of the public API." The module path is your access control.

**Rationale:** Nothing stops a user from writing `require("cubby.core.filename").build_sorted_filename(...)` and depending on that signature. Without a textual marker, the day you refactor that signature, you break someone. In a language without access modifiers, you must do it with words and structure.

**Violation:** An internal module with no annotation about its stability. A user depends on it, files a bug when the signature changes, and the maintainer cannot point to any documented contract.

### 2. Cap function parameters at three; use named tables beyond that

No function accepts more than three positional parameters. When a function needs four or more inputs, pass a table with named fields annotated with LuaCATS.

**Rationale:** Positional parameters of the same type are ordered by convention, and convention is the first thing forgotten under deadline pressure. Named fields are self-documenting and order-independent. Five positional string parameters are a bug factory — the caller transposes two arguments and gets wrong output with no error.

**Violation:** `build_filename_for_sort(new_label, original_filename, timestamp, ext, marker)` — five string parameters. A caller writes them in the wrong order and the filename is silently wrong. With a named table, the call site is self-documenting.

### 3. Make every public function's return type honest and uniform

Functions that are interactive side-effects return nothing and are documented as such. Functions that produce values return `value, error` consistently. Never return `nil` without the caller knowing why.

**Rationale:** When `new_note()` returns a path or nil but `sort_note()` returns whatever the internal function returns (undocumented), a user scripting the API cannot predict the behavior. Every public function must state: "I return X" or "I am interactive and return nil."

**Violation:** A public API function whose return value is defined by internal implementation details that bleed through. The user writes `local result = cubby.sort_note()` and has no idea what `result` is.

### 4. Treat LuaCATS annotations as load-bearing architecture

Every data contract must be defined in exactly one place with every field annotated. Every function that produces or consumes these types must reference them by name. An unannotated public field is a bug. An anonymous table is ungreppable.

**Rationale:** You have no compiler and no runtime type checker. LuaCATS annotations are the only thing standing between your data contracts and chaos. But annotations only work if they are complete, canonical, and referenced consistently.

**Violation:** A function that returns `{ recent = entries_table }` where the wrapper table shape is never annotated. If someone changes the key from `recent` to `entries`, no tooling catches it. Named types are greppable. Anonymous tables are not.

### 5. Reject unknown configuration keys at setup time

`setup()` must warn on configuration keys that do not exist in the default config. Silent acceptance of typos is the single most common source of user frustration in Neovim plugin configuration.

**Rationale:** A user writes `inbox_directory` instead of `inbox_dir`, gets no error, and spends thirty minutes wondering why their config is not working. `vim.tbl_deep_extend` silently merges anything — including typos and keys from another plugin's config that was copy-pasted.

**Violation:** A setup function that accepts any table and merges it without checking for unknown keys. The user's typo becomes a silent no-op, and the default value persists without explanation.

### 6. State invariants as predicates; decide where to check them

For every invariant the system relies on, write an explicit boolean predicate. Then make a deliberate decision about where that predicate is evaluated — at the boundary, at the call site, or never. An invariant that exists only in a developer's head is not an invariant.

**Rationale:** A timestamp format that must produce strings matching a specific pattern is an invariant. Validating it once at setup is good. But if timestamp strings enter filenames through a path that does not go through the validated config, the invariant is silently violated. The predicate should be reusable as a standalone guard.

**Violation:** A validation function that checks format-pattern coupling at setup time but is never reused. A fallback code path returns a timestamp that was never validated against the pattern, because the predicate is buried in config validation instead of being a standalone callable check.

### 7. Design callbacks with a single structured argument; nil means cancelled

Every UI function that takes a callback passes it exactly one argument: a structured result table (or nil for cancellation). Never pass multiple positional values. Never overload the meaning based on context.

**Rationale:** Callbacks in Lua have no enforced type signature. When a callback receives multiple positional arguments, you get the same transposition bugs as positional parameters, but worse — the bug is separated in time and space from the function that caused it.

**Violation:** A callback that passes `(dir, is_recent, timestamp)` as three positional arguments to a handler. The handler transposes `is_recent` and `timestamp` and gets a silent type mismatch. With a single `{ dir = ..., is_recent = ..., timestamp = ... }` table, the fields are named and self-documenting.

## Anti-Patterns

### Undocumented internal modules
Internal modules with no "not part of public API" annotation. Users treat them as stable. Refactoring breaks them. The maintainer is blamed for a contract they never made.

### Five-parameter functions
Functions with more than three positional parameters of the same type. The caller must remember the order, and transposition errors produce wrong output with no diagnostic.

### Warnings instead of enforcement
A config validation that detects an invalid value, logs a warning, and continues with the invalid value. The system is now running with a configuration it has identified as incorrect, and every subsequent failure is the maintainer's fault.

### Anonymous data shapes
Functions that return untyped tables whose structure is defined only by the code that constructs them. When the structure changes, no annotation flags it, no search finds all consumers.

### Silent acceptance of bad config
A `setup()` function that merges unknown keys without comment. Typos become invisible failures. Users blame the plugin for "not working" when their configuration was never applied.
