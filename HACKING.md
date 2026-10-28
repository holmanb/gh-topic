# Hacking on gh-topic

`gh-topic` is a single bash script; there is nothing to build.

## Checks

```bash
shellcheck gh-topic
shfmt --list --case-indent --indent=4 --space-redirects --simplify gh-topic
```

`shellcheck` passes with no overrides: no `# shellcheck disable=`
directives, no `--exclude` flags. `shfmt --list` prints the files that
need formatting; it must print nothing.

## Tests

The regression suite runs `gh-topic` against fixture repos with a
stubbed `gh`:

```bash
bash tests/run-tests.sh
```

## Style

- Comments get a line of their own, above the code they describe;
  no trailing comments.
- Comments state why the code does something, never what or how;
  describing behavior is the job of the comment above a function.
- Helpers are named for an action on an object: `clone_topic`,
  `copy_remotes`, `unmerged_changes`.
- In the README, edge cases go under `## Notes`, and a fact is stated
  in one section only.