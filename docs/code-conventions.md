# Code Conventions

**Thesis:** Every file in this codebase should read the same way — same require strategy, same error pattern, same structural conventions — so that understanding one module teaches you how to read all of them.

## Principles

### 1. Use lazy requires everywhere, and do it the same way every time

All `require()` calls go at the top of the function that uses them, not at module scope. No exceptions across any layer.

**Rationale:** A convention that applies "sometimes, depending on the layer" is not a convention — it is a source of confusion. Lazy requires prevent loading modules before `setup()` has been called and keep Neovim startup fast. The cost is a few repeated lines per function. The benefit is that every file in the project works the same way.

**Violation:** A core module with `local fs = require("cubby.core.fs")` at the top of the file, while every note-layer module requires inside function bodies. A reader who sees the top-level require assumes that is the convention, then is surprised when another module does it differently.

### 2. Name functions for what they return, not what they do internally

The caller wants to know what they get back. The implementation details are the function's business. If a function returns a filename, name it for the filename, not for the process.

**Rationale:** The test is: can you read the call site without looking up the definition? `local name = filename.sorted_name(label, ts, ext, marker)` reads clearly. Adding verbs like "build" or suffixes like "for_sort" either add no information or describe the caller's intent, which the function cannot know.

**Violation:** A function called `extract_label_and_remainder` where the "remainder" is actually a timestamp. Call it what it is. The next reader should not need to open the function to discover that "remainder" means "timestamp string."

### 3. One error convention — value, error — with zero exceptions

Every function that can fail returns `value, error_string`. Use `assert` only for conditions that indicate a bug in cubby itself (violated internal invariants that should be impossible), never for operational failures like missing config or bad input.

**Rationale:** When every function speaks the same error language, callers learn one pattern and apply it everywhere. One function that throws in a chain of functions that return errors creates a trap — the caller who has learned to check the second return value will not wrap this call in `pcall`.

**Violation:** A time-formatting function that uses `assert(fmt, "format required")` while every other function in the codebase returns `nil, "error message"` for the same class of problem. A caller writes `local stamp = time.now_stamp(cfg.timestamp_fmt)` without pcall and gets a stack trace instead of a handleable error.

### 4. A module earns its file by having multiple callers or encapsulating non-trivial logic

A file is a unit of cognitive overhead. Every module should pass this test: if you deleted this file and moved its contents into the one or two files that use it, would the code get harder to read? If not, the module has not earned its file.

**Rationale:** Too many files and the reader spends more time navigating than reading. Too few and individual files become hard to hold in your head. The sweet spot is: a file exists because it has weight — multiple callers, a coherent concept, or enough complexity that extraction aids comprehension.

**Violation:** A wrapper module that is 26 lines containing three functions, where two are one-line pass-throughs and one checks a single boolean before delegating. The wrapper adds no logic, enforces no invariant, and isolates no dependency that might actually change. Inline the logic at the call site.

### 5. Comments explain decisions; names and types explain everything else

Type annotations document the interface. Function names document the intent. Comments document the *why* — the choice between two reasonable alternatives, the reason a magic number has that value, the tradeoff being accepted.

**Rationale:** A comment that restates the code is noise. A comment that explains a decision is the only documentation that survives refactoring. Magic numbers, special-cased thresholds, and workarounds for other plugins all deserve a one-line explanation.

**Violation:** A relative-time function with thresholds like `5184000` and `2592000` and no comment explaining what those numbers represent or why certain ranges get special treatment (e.g., "1 month ago" has a wider band than "1 day ago"). The next reader must do arithmetic to understand the design.

### 6. Handle errors at the point where you can write a good message

An error message is good when it tells the user what happened and what to do about it. Only the caller who knows the full context can write that message. Low-level functions should return the raw error; high-level functions should format the user-facing message.

**Rationale:** When a filesystem write function returns a bare boolean with no error string, the caller must either invent a vague message ("Failed") or swallow the error silently. Meanwhile, `io.open` already provides the OS-level error message for free. Pass it through.

**Violation:** A file-write function that returns `false` on failure, discarding the error reason that `io.open`'s second return value already provides. The user sees "Failed to create note" with no indication of whether it was a permissions problem, a disk-full problem, or a missing directory.

### 7. Similar-looking functions with different policies must document the difference

When two functions appear to do the same thing (e.g., sanitize user input into a safe string) but have legitimately different rules, each must state what it strips, what it preserves, and why. Undocumented divergence between similar functions is a bug waiting to happen.

**Rationale:** Different invariants deserve different code — a label sanitizer that strips to `[a-z0-9-]` and a directory name sanitizer that preserves `/._ ` are genuinely different operations. But when the difference is implicit and the return-type conventions differ (empty string vs. nil), the next developer will use the wrong one.

**Violation:** Two sanitization functions with similar gsub chains but different character allowlists, different casing rules, and different return types for invalid input, living in different files with no comment explaining why they diverge.

## Anti-Patterns

### Inconsistent require strategy
Top-level requires in some modules, function-level requires in others, with no documented rule for when to use which. The reader cannot build a mental model of the project's loading behavior.

### Assert in an error-return codebase
Using `assert()` for input validation in a project where every other function returns `nil, error_string`. This creates a hidden control flow exception that callers are not prepared to handle.

### Wrapper modules with no value-add
A module whose only job is to rename a standard API call. If the wrapper does not encapsulate non-trivial logic, enforce an invariant, or isolate a dependency that might change, it is overhead without benefit.

### Magic numbers without context
Numeric constants in conditional chains where the reader must do arithmetic to understand the thresholds. A one-line comment per magic number is cheaper than the debugging time it saves.

### Vague error messages
Error handlers that say "Failed" without specifying what failed, why, or what the user should try. Error messages are user interface — they deserve the same care as prompts and notifications.
