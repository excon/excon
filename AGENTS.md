# AGENTS.md

Guidance for AI coding agents (and humans) working in this repository.

## Project

excon is a pure-Ruby HTTP(S) client library.

- The only runtime dependency is `logger`. Don't add runtime gems; test/dev
  tooling goes in the gemspec's development dependencies or the `Gemfile`.
- Supports Ruby >= 3.3 and JRuby; CI runs 3.3, 3.4, 4.0, head and jruby.
- Backwards compatibility matters: keep public APIs and legacy aliases (e.g.
  `Excon::Errors::*` alongside `Excon::Error::*`) working.

## Layout

- `lib/excon.rb`, `lib/excon/` — the library (`connection.rb`, socket classes,
  `middlewares/`, `instrumentors/`). Only `lib/`, `data/` and top-level docs
  ship in the gem.
- `data/cacert.pem` — bundled CA certs. Don't edit by hand; use
  `rake update_certs` (which also regenerates the test certs in `tests/data/`).
- `tests/` — shindo tests, plus shared fixtures used by both suites:
  `tests/rackups/` (rack apps), `tests/servers/` (raw socket servers),
  `tests/data/` (certs, files).
- `spec/` — rspec tests; `spec/support/` holds the test server harness
  (`Excon::Test::Server`) and shared examples/contexts.

## Tests

The suite is split across two frameworks and is being migrated, gradually,
to **minitest**. Shindo (`tests/`) and rspec (`spec/`) are both legacy.

Until the minitest suite exists:

- Add new tests to `spec/`, never to `tests/`.
- Don't move or rewrite existing tests as a side effect of an unrelated
  change; migration happens in dedicated PRs.

Running tests:

```sh
bundle exec rake                        # everything (what CI runs)
bundle exec rake tests                  # shindo only
bundle exec rake spec                   # rspec only
bundle exec shindo tests/utils_tests.rb # one shindo file
bundle exec rspec spec/excon/error_spec.rb
```

Notes:

- Test servers bind fixed ports (9292, 9443, 8443, 1080), so run suites
  serially, not in parallel.
- Some tests need outbound DNS (the resolver specs look up `google.com`) or
  IPv6 loopback (`::1`). In sandboxes without those they fail for
  environmental reasons, not because of your change; check whether they
  also fail without it.

## Conventions

- Add a line under "Unreleased" in `changelog.txt` for user-visible changes.
- RuboCop (`bundle exec rubocop`) is configured but not enforced, and the
  existing code has many offenses. Treat it as advisory: fix offenses in lines
  you change, don't reformat code you aren't otherwise touching.
- Keep PRs focused; unrelated cleanup goes in its own PR.
