# AGENTS.md

Guidance for AI coding agents (and humans) working in this repository.

## Project

excon is a pure-Ruby HTTP(S) client library.

- There are no runtime dependencies. Keep it that way: test/dev tooling goes
  in the gemspec's development dependencies or the `Gemfile`.
- Supports Ruby >= 3.3 and JRuby; CI runs 3.3, 3.4, 4.0, head and jruby.
- Backwards compatibility matters: keep public APIs and legacy aliases (e.g.
  `Excon::Errors::*` alongside `Excon::Error::*`) working.

## Layout

- `lib/excon.rb`, `lib/excon/` — the library (`connection.rb`, socket classes,
  `middlewares/`, `instrumentors/`). Only `lib/`, `data/` and top-level docs
  ship in the gem.
- `data/cacert.pem` — bundled CA certs. Don't edit by hand; use
  `rake update_certs` (which also regenerates the test certs in
  `test/fixtures/data/`).
- `test/` — minitest tests (see below).
  `test/support/test_server.rb` runs a test server around a test class,
  using `test/support/in_process_server.rb`, which runs the fixture servers
  in a thread of the test process.
- `test/fixtures/` — test fixtures: `rackups/` (rack apps), `servers/` (raw
  socket servers), `data/` (certs, files).

## Tests

Tests are in **minitest**, in `test/`, with fixtures in `test/fixtures/`.

- Add new tests to `test/` (files named `*_test.rb`), in the subdirectory
  matching the code under test (`middlewares/`, `instrumentors/`) or at the
  top level, e.g. `test/timeout_test.rb`.
- For tests that need a server, `include TestServer` and declare
  `test_server :webrick, 'basic.ru'` (see `test/support/test_server.rb`).
  Shared helpers go in `test/support/`.
- Minitest shuffles test order, so each test sets up what it needs rather
  than relying on state from another.
- One behavior per test, named for it. Assert step by step, with a short
  comment where a value needs explaining, and explain at the top of the file
  what a fixture endpoint reports if that isn't obvious.
- Check a new test can fail: break the code under test (e.g. `-r` a file
  that monkeypatches it) and make sure the right tests fail.

Running tests:

```sh
bundle exec rake                           # everything (what CI runs)
bundle exec ruby -Itest test/utils_test.rb # one file
```

Notes:

- Test servers bind fixed ports (9292, 9443, 8443, 1080), so run suites
  serially, not in parallel.
- Some tests need IPv6 loopback (`::1`). In sandboxes without it they fail for
  environmental reasons, not because of your change; check whether they
  also fail without it.

## Conventions

- Add a line under "Unreleased" in `changelog.txt` for user-visible changes.
- RuboCop (`bundle exec rubocop`) is configured but not enforced, and the
  existing code has many offenses. Treat it as advisory: fix offenses in lines
  you change, don't reformat code you aren't otherwise touching.
- Keep PRs focused; unrelated cleanup goes in its own PR.
