# Development workflow

Use test-driven development for new behavior and bug fixes, as requested by the user.

1. Write a focused test for the desired observable behavior.
2. Run it and confirm it fails for the intended reason before changing production code.
3. Implement the smallest change that makes it pass.
4. Refactor with tests passing, then run the relevant regression suite.

Do not describe tests added after an implementation as TDD. For refactors, preserve behavior and keep the existing suite green. Keep persistence tests isolated from real player saves. Prefer meaningful rules, persistence, and interaction tests over checks of implementation details.

Run `make test` for headless rules and save tests. Run `make playtest` for input, animation, or layout changes. Web-specific changes use `tests/web_playtest.cjs` against a freshly exported local web build.
