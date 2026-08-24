# AGENTS

Git playground is project to test a git client, a playground to test differents use cases.

## GitHub fixtures

`scripts/seed-github.sh` rebuilds a set of pull requests covering every GitHub surface Reviu reads:
open/draft/closed/merged, conflicting, approved, changes requested, comment threads
(unresolved, resolved, outdated, reply chains, unsubmitted pending review), the full check
rollup, a heavy diff (rename, delete, binary, truncated patch), a PR from a fork, and a stack.

Everything it creates lives under the `fx/` branch namespace and nothing outside it is touched.

```sh
./scripts/seed-github.sh                 # rebuild the whole set
./scripts/seed-github.sh --only 07,08    # rebuild a subset (the purge is scoped to it)
./scripts/seed-github.sh --report        # print live state, write scripts/fixtures.json
./scripts/seed-github.sh --purge-only    # delete every fx/ PR and branch
./scripts/seed-github.sh --with-actions  # also push a real workflow (burns runner minutes)
```

Two GitHub accounts must be authenticated, since GitHub forbids reviewing your own PR:
`joris-gallot` (owner) and `joris-gallot-bot` (author of most fixtures, so the owner can
approve, comment and resolve threads). Add one with `gh auth login`; the script reads both
through `gh auth token -u <account>` and never switches the active account.

The `fx/02-conflict` fixture pushes a commit to `main` on purpose: that commit is what makes
the PR conflict.

## Private repo limitations

The repo is private on a free plan, which blocks two fixtures:

- **Auto-merge** is rejected (`allow_auto_merge` silently stays `false`), so `fx/12-automerge`
  exists but is never armed.
- **Branch protection / rulesets** are unavailable, so there is no "merge blocked by a required
  check" fixture. Blocked-by-conflict, blocked-by-draft and changes-requested still work.

Actions minutes are also billed on a private repo, which is why checks are seeded through the
Statuses API by default (instant and free) and `--with-actions` is opt-in.

Making the repo public lifts all three at once; nothing in the script needs to change.
