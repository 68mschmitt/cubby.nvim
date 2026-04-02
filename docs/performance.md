# Performance

**Thesis:** This plugin's performance strategy is to stay synchronous, stay simple, bound the worst case, and never add optimization complexity without a measured regression to justify it.

## Principles

### 1. Never block the main loop for longer than one frame

Any synchronous operation that could exceed 16ms under realistic worst-case conditions must be bounded with a hard cap. Neovim is a single-threaded event loop — blocking it freezes the cursor and redraws.

**Rationale:** At 50 files with warm filesystem caches, a directory scan takes under 1ms. But if someone points their inbox at a directory with 5,000 files on a network mount, synchronous stat calls can freeze the editor for seconds. The fix is not async — it is a circuit breaker. Cap the scan, warn the user, and keep the synchronous simplicity for the 99% case.

**Violation:** A directory scan that iterates all files and calls `fs_stat` on each one with no upper bound. At 50 files this is invisible. At 5,000 files on NFS, it is a frozen editor.

### 2. Pay for defense where mutation is possible; do not pay where it is not

Use defensive copies (`vim.deepcopy`) only at boundaries where the caller could actually mutate shared state. For internal read-only access within a single command execution, pass the table directly.

**Rationale:** Copying a 13-field config table with a nested array is cheap in absolute terms (~2-5μs on LuaJIT). But when it happens 4-6 times per command invocation — once per helper function that independently calls `config.get()` — you are creating throwaway tables that pressure the GC for zero safety benefit. No internal caller ever mutates the config. The defensive copy is cargo cult programming, not defensive programming.

**Violation:** A notification function that deep-copies the entire config table — including an array field — to read a single boolean. Called on every command invocation.

### 3. Lazy requires are the right default — do not "fix" them

Keep `require()` calls inside function bodies for user-invoked commands. Do not hoist them to module scope to avoid hash lookups.

**Rationale:** Lua's `require()` checks `package.loaded` — a hash lookup that takes ~20-50 nanoseconds on LuaJIT. Five requires per command invocation cost ~300ns total. The user invokes commands by pressing keys with their fingers; the latency between their brain and the keypress is ~100ms. Meanwhile, the benefit of lazy requires is real: every top-level require runs during startup. Eagerly requiring all modules adds measurable milliseconds to Neovim's launch. Users notice startup time. Users do not notice 300 nanoseconds.

**Violation:** Hoisting all requires to module scope "for performance." This makes startup slower, gains nothing measurable on the hot path, and creates load-order dependencies that break when modules are required before `setup()`.

### 4. Do I/O once per user action, not once per helper function

Load shared state (config, MRU file, directory listings) once at the top of a command's execution path and thread it through as arguments. Never let two helper functions independently hit disk for the same data.

**Rationale:** When `add_recent_entry` reads the JSON file and `get_recent_list` also reads it, and both are called in the same command flow, you are reading and parsing the same file twice. The parse time (~10-50μs for a 5-entry list) is negligible, but the pattern means every function owns its own I/O, and you cannot reason about the I/O behavior of a command without reading every function it calls.

**Violation:** A single note-sorting command that triggers 4 config deep-copies and 2 disk reads across its call chain because each helper independently loads what it needs. Read once. Pass the data in.

### 5. Your latency budget is 100ms; the user's picker owns 90% of it

Measure your plugin's latency as the time from keypress to `vim.ui.select` appearing. Budget 10ms for your code. The picker UI — Telescope, fzf-lua, or built-in — takes the rest.

**Rationale:** Under 100ms feels instant to humans. The plugin's job before handing off to the picker is: read config, scan a directory, build display strings, and call the picker. At 50 files with warm caches, this should be 1-3ms. You should know this from measurement, not assumption.

**Violation:** Nobody has measured the hot path. There is no profiling instrumentation anywhere. Add `vim.uv.hrtime()` timing once, record the number, and write it down. If someone later asks "is this fast enough," point to the measurement instead of the hope.

### 6. Bound your worst case with hard limits, not hope

Any loop that scales with external input — filesystem contents, collision counts, user data — must have an explicit upper bound and a clear degradation path when that bound is hit.

**Rationale:** A collision-resolution loop with a default limit of 1000 iterations means 1000 stat calls in the worst case. On a local SSD, that is ~1-2ms. On NFS, it could be 5 seconds. But the deeper issue is: if you have more than a handful of collisions on a filename, something is fundamentally wrong and the user needs to know, not wait.

**Violation:** A uniqueness check that loops up to 1000 times checking file existence. Lower the bound to something meaningful (e.g., 20) and tell the user their naming scheme has a problem when it is exceeded.

### 7. Never optimize without a regression to point to

Do not add caching, async I/O, or architectural complexity to solve a performance problem that no user has reported and no measurement has confirmed. The current synchronous codebase is ~1,200 lines of straightforward Lua where every line is easy to reason about. That simplicity is a feature.

**Rationale:** Adding async means: callback ordering bugs, error handling in two contexts, potential race conditions on shared state, and cognitive overhead for every future contributor. That cost is real and permanent. The benefit — saving a few milliseconds the user cannot perceive — is imaginary. Keep it synchronous. Keep it simple. If a user reports a real performance problem, then profile, then fix the specific bottleneck.

**Violation:** Making the inbox scanner async "because synchronous I/O is bad." The code triples in size, gains coroutine error handling complexity, requires `vim.schedule()` for API access, and saves 1ms on a path that takes 2ms total. The user cannot perceive the improvement. The next contributor cannot understand the code.

## Anti-Patterns

### Premature async
Converting synchronous operations to async/coroutine patterns without a measured performance problem. This trades simple, debuggable code for complex code with subtle ordering and error-handling bugs.

### Repeated I/O for the same data
Multiple functions in the same call chain independently reading the same file from disk or copying the same config. Load once at the entry point and pass the data down.

### Unbounded iteration
Loops that scale with external input (file counts, collision counts) without explicit caps. The 99% case works fine; the 1% case freezes the editor.

### Defensive copies on every read
Using `vim.deepcopy` on every `config.get()` call when no internal caller ever mutates the config. Pay the copy cost only at the trust boundary where external code touches your data.

### Optimizing without measuring
Adding caching, pooling, or complexity to code paths that have never been profiled. The time spent on the optimization exceeds the time it will ever save.
