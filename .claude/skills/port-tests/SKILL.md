---
name: port-tests
description: Port a shindo (tests/) test file to minitest (test/). Use when asked to migrate, port or convert existing tests.
---

# Porting tests to minitest

Goal: move every test from `tests/` (shindo) into `test/` (minitest), one
file per PR, deleting the originals, until only fixtures remain.

Keep this guide to about one screen. Add to it only when a pattern shows up
in a second file or a port went wrong in review because something was
missing; otherwise note it in the PR description. Prefer a helper in
`test/support/` over more prose here. Delete this skill when the migration
is done, moving anything still useful into `AGENTS.md`.

## Principles

1. **Check the same things as the original.** Each real check becomes an
   assertion; drop nothing silently. If the same cases exist in both suites,
   port the union and delete both. If an original check never asserted
   anything, or the port finds a real bug, call it out rather than quietly
   fixing or dropping it.
2. **Each test stands alone.** Minitest shuffles test order, so a test can't
   rely on state from another; repeat the setup it needs.
3. **Readable without the history.** One behavior per test, named for it.
   Assert step by step, with a short comment where a value needs explaining,
   rather than comparing arrays the reader has to replay. Explain at the top
   of the file what a fixture endpoint reports, if that isn't obvious.
4. **Prove it can fail.** Before opening the PR, break the code under test
   (e.g. `-r` a file that monkeypatches it) and check the right tests fail.

## Translation

| Shindo / rspec | Minitest |
|---|---|
| `returns(x) { ... }` | `assert_equal x, ...` (also for `true`/`false`; `refute` passes on `nil`) |
| `returns([a, b, ...])` over a sequence of results | one `assert_equal` per element, each commented with what it shows (see `test/request_test.rb`) |
| `raises(E) { ... }`, `begin ... rescue E` | `error = assert_raises(E) { ... }`, then assert on `error` |
| `test('...') { bool }` | `assert ...` |
| `pending` | `skip 'reason'` |
| nested `tests` / `describe` | one class per file (or per server), flat `test_` method names |
| `with_rackup`, `with_server`, `include_context 'test server'` | `include TestServer` + `test_server :webrick, 'basic.ru'` |

## Reference ports

- `test/utils_test.rb`: plain translation, no server.
- `test/error_test.rb`: union of shindo and rspec copies; server tests in
  their own class.
- `test/request_test.rb`: the same tests against several servers (module
  plus one class per server); state shared between shindo blocks; skipping
  where a server can't run.

## Before opening the PR

- Count real checks in the original against assertions in the port. Shindo's
  pass count can be off (e.g. a `test` used as a group counts as a pass).
- Delete the originals; the destination path follows `AGENTS.md`.
- Run the file with a few `--seed`s, then `bundle exec rake test`.
- `bundle exec rubocop` on the new file: no offenses.
- In the PR description, list what moved where, anything dropped or fixed
  and why, and the fault you injected.
