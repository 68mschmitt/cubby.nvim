# Testing

**Thesis:** Tests exist to make change safe. Every test should make you braver about tomorrow's refactor; every test that does not is weight carried for free.

## Principles

### 1. Test decisions, not plumbing

A test earns its keep when it verifies a decision the code makes — a branch, a transformation, a policy. Not that Lua can call a function and get a callback.

**Rationale:** If you find yourself asserting that a function was called rather than asserting what happened as a result, you are testing plumbing. Plumbing tests break when you change wiring, and they never catch real bugs. Decision tests — "invalid input triggers re-prompt," "collision appends a counter" — verify behavior that matters.

**Violation:** A test that asserts `vim.ui.input` was called with a specific prompt string. This test breaks when you change the prompt wording and never catches a logic bug. Instead, test that the callback receives the right value for a given input.

### 2. Push logic down into testable functions; test it there

The cheaper a function is to test, the more tests you will write and the more confidently you will refactor. When a test requires elaborate setup — filesystem, config, buffer manipulation — that is a design signal, not a testing problem.

**Rationale:** Pure functions in `core/` are the cheapest tests. If a note-layer function mixes computation with side effects, extract the computation and test it independently. The note-layer integration test then only verifies that the pieces compose correctly.

**Violation:** Testing filename generation by configuring the entire plugin, creating a temp directory, invoking the full creation flow, and then regex-matching the resulting path. The filename logic is testable with a pure function call — `build_sorted_filename("label", "2025-01-01_00-00-00", ".md", "--note")` — that needs zero setup.

### 3. Stub at the boundary you do not own; never stub your own code

Replace `vim.ui.input`, `vim.ui.select`, and `vim.notify` in tests — those are Neovim APIs you cannot control. Never stub your own core modules inside integration tests. The point of a note-layer test is to verify that your modules compose correctly; stubbing one of them defeats that purpose.

**Rationale:** A note-layer test that stubs `filename.ensure_unique` to return a known string, then asserts the path contains that string, tests nothing that the core-layer tests do not already test. You have paid the cost of a test and received no new information.

**Violation:** An integration test for the sort flow that replaces `move.move_file` with a no-op. This test cannot catch filesystem bugs — which are the exact bugs the integration test should find.

### 4. If it touches the filesystem, test it with a real filesystem

Filesystem behavior is the one thing in this codebase that will actually surprise you — permissions, path separators, race conditions, cross-platform differences. The temp-directory-per-test pattern with cleanup in `after_each` is the correct cost to pay.

**Rationale:** Mocking `fs.file_exists` to return `true` and then asserting that `ensure_unique` appends `--2` would pass even if `file_exists` had a trailing-slash bug on CI. The filesystem is a boundary you do not stub.

**Violation:** A test for file collision handling that simulates collisions by mocking the existence check instead of creating actual files. The test passes, but the code fails when filenames contain spaces on Windows.

### 5. Every stub must be installed in before_each and restored in after_each

If your teardown depends on your test not throwing, your test suite becomes order-dependent — the most insidious kind of test failure. All stub installation and restoration belongs in lifecycle hooks, not in the test body.

**Rationale:** If an assertion fails before `vim.ui.input = original` executes inline, every subsequent test runs with a stubbed input. In a 40-test suite, you will spend an afternoon debugging a test that only fails when run after another test.

**Violation:** A UI test that saves `original_input = vim.ui.input` at the start of the test body, replaces it, and restores it at the end. The restore line never runs if the assertion in the middle throws.

### 6. Test config effects, not config storage

A test that asserts `config.get().file_ext == ".md"` is testing a data literal. It will never catch a real bug and will break every time you change a default. The valuable tests verify that config values flow through to behavior.

**Rationale:** The interesting question is never "was this value stored correctly" — it is "when this value changes, does the output change accordingly." Set `file_ext = ".txt"` and verify the created filename ends in `.txt`. That test survives refactoring of the config internals.

**Violation:** A config test that asserts every default value matches a hardcoded expected table. When you change `trailing_marker` from `"--note"` to `"--n"`, this test fails, you update the expectation, and you have learned nothing. Meanwhile, no test verifies that changing the marker actually changes the filenames.

### 7. Consciously choose what not to test — and write it down

Not everything deserves a test. A test is an investment with a maintenance cost. The return on that investment is confidence to change. Some code does not change, or its failure mode is obvious and low-cost. The discipline is not "test everything" — it is "for every untested module, make a conscious decision and document it."

**Rationale:** A diagnostic health-check module that runs on user request and prints status messages has a self-evident failure mode — if it breaks, the user sees a Lua traceback in the health check itself. Writing tests for it means stubbing Neovim's health API, and those tests would verify plumbing. The cost exceeds the value.

**Violation:** Leaving a module untested by accident. Every intentional gap should be stated: "This module is not tested because its failure mode is self-evident and low-cost." That is a decision. An empty test directory is an oversight.

## Anti-Patterns

### Testing call order instead of outcomes
Asserting that function A was called before function B, instead of asserting the final filesystem state. Call order is an implementation detail; the outcome is the contract.

### Inline stub restoration
Saving and restoring `vim.ui.input` inside the test body instead of in `before_each`/`after_each`. Any assertion failure between save and restore leaves the stub in place for all subsequent tests.

### Config default assertion suites
A block of tests that assert every default value matches a literal. These tests have high maintenance cost, zero bug-finding value, and they actively fight you during every configuration change.

### Mocking the filesystem
Replacing `fs.file_exists` or `fs.write_file` with stubs in tests that are supposed to verify filesystem behavior. This gives false confidence about the one layer most likely to betray you.

### Untested code without a stated reason
Modules with no test file and no documentation explaining why. Every gap should be a choice, not an omission.
