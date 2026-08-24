#!/usr/bin/env bash
# Recreates the GitHub PR fixture set that exercises Reviu's GitHub surfaces.
# Everything it creates lives under the fx/ branch namespace; nothing else is touched.
set -euo pipefail

REPO="${REPO:-joris-gallot/git-playground}"
ME="${ME:-joris-gallot}"
BOT="${BOT:-joris-gallot-bot}"
WITH_ACTIONS="${WITH_ACTIONS:-0}"
ONLY=""
PURGE_ONLY=0
REPORT_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="$2"; shift 2 ;;
    --purge-only) PURGE_ONLY=1; shift ;;
    --with-actions) WITH_ACTIONS=1; shift ;;
    --report) REPORT_ONLY=1; shift ;;
    -h|--help)
      sed -n '2,4p' "$0"
      echo "usage: $0 [--only 02,07] [--purge-only] [--with-actions] [--report]"
      exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

die()  { echo "error: $*" >&2; exit 1; }
warn() { echo "warn: $*" >&2; }
step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

command -v gh >/dev/null || die "gh CLI not found"

ME_TOKEN=$(gh auth token -u "$ME" 2>/dev/null)  || die "no gh auth for $ME"
BOT_TOKEN=$(gh auth token -u "$BOT" 2>/dev/null) || die "no gh auth for $BOT. Run: gh auth login  (pick $BOT), then gh auth switch -u $ME"

gh_me()  { GH_TOKEN="$ME_TOKEN"  gh "$@"; }
gh_bot() { GH_TOKEN="$BOT_TOKEN" gh "$@"; }

OWNER="${REPO%%/*}"
NAME="${REPO##*/}"
BOT_ID=$(gh_me api "users/$BOT" -q .id)
ME_ID=$(gh_me api "users/$ME" -q .id)
BOT_EMAIL="${BOT_ID}+${BOT}@users.noreply.github.com"
ME_EMAIL="${ME_ID}+${ME}@users.noreply.github.com"

wants() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; esac
  return 1
}

# fx/07-changes -> 07, so --only never purges fixtures it is not rebuilding
purge_match() {
  case "$1" in fx/*) ;; *) return 1 ;; esac
  local id="${1#fx/}"
  wants "${id%%-*}"
}

# ---------------------------------------------------------------- github glue

report() {
  local fields=number,title,state,isDraft,mergeable,headRefName,baseRefName,author,reviewDecision
  gh_me pr list --repo "$REPO" --state all --limit 200 --json "$fields" \
    -q '[.[] | select(.headRefName | startswith("fx/"))] | sort_by(.number)' \
    > "$SCRIPT_DIR/fixtures.json"
  printf '\n\033[1m== fixtures\033[0m\n'
  printf '%-5s %-8s %-10s %-13s %-18s %s\n' PR STATE DRAFT MERGEABLE REVIEW BRANCH
  gh_me pr list --repo "$REPO" --state all --limit 200 --json "$fields" \
    -q '.[] | select(.headRefName | startswith("fx/"))
        | [(.number|tostring), .state, (.isDraft|tostring), .mergeable,
           (.reviewDecision // "-"), (.headRefName + (if .baseRefName == "main" then "" else " -> " + .baseRefName end))]
        | @tsv' \
    | sort -n \
    | while IFS=$'\t' read -r n st dr mg rv br; do
        printf '#%-4s %-8s %-10s %-13s %-18s %s\n' "$n" "$st" "$dr" "$mg" "$rv" "$br"
      done
  printf '\nfixtures.json written to %s\n' "$SCRIPT_DIR/fixtures.json"
  printf 'https://github.com/%s/pulls\n' "$REPO"
}

ensure_collaborator() {
  if gh_me api "repos/$REPO/collaborators/$BOT" --silent >/dev/null 2>&1; then return; fi
  step "inviting $BOT as collaborator"
  gh_me api -X PUT "repos/$REPO/collaborators/$BOT" -f permission=push --silent
  local id
  id=$(gh_bot api user/repository_invitations -q ".[] | select(.repository.full_name==\"$REPO\") | .id" | head -1)
  [ -n "$id" ] && gh_bot api -X PATCH "user/repository_invitations/$id" --silent
}

pr_new() { # who head base title body [extra gh flags...]
  local who="$1" head="$2" base="$3" title="$4" body="$5"; shift 5
  local url
  if [ "$who" = bot ]; then
    url=$(gh_bot pr create --repo "$REPO" --head "$head" --base "$base" --title "$title" --body "$body" "$@" | tail -1)
  else
    url=$(gh_me  pr create --repo "$REPO" --head "$head" --base "$base" --title "$title" --body "$body" "$@" | tail -1)
  fi
  echo "${url##*/}"
}

status_set() { # sha state context description
  gh_me api "repos/$REPO/statuses/$1" \
    -f state="$2" -f context="$3" -f description="$4" \
    -f target_url="https://example.com/ci/$3" --silent
}

node_id_of_pr() {
  gh_me api graphql -f owner="$OWNER" -f name="$NAME" -F number="$1" -q '.data.repository.pullRequest.id' -f query='
    query($owner:String!,$name:String!,$number:Int!){
      repository(owner:$owner,name:$name){ pullRequest(number:$number){ id } } }'
}

thread_ids() {
  gh_me api graphql -f owner="$OWNER" -f name="$NAME" -F number="$1" \
    -q '.data.repository.pullRequest.reviewThreads.nodes[].id' -f query='
    query($owner:String!,$name:String!,$number:Int!){
      repository(owner:$owner,name:$name){
        pullRequest(number:$number){ reviewThreads(first:50){ nodes{ id isResolved } } } } }'
}

resolve_thread() {
  gh_me api graphql -F threadId="$1" --silent -f query='
    mutation($threadId:ID!){ resolveReviewThread(input:{threadId:$threadId}){ thread{ id } } }'
}

enable_automerge() {
  local id; id=$(node_id_of_pr "$1")
  gh_me api graphql -F pullRequestId="$id" --silent -f query='
    mutation($pullRequestId:ID!){
      enablePullRequestAutoMerge(input:{pullRequestId:$pullRequestId,mergeMethod:SQUASH}){ clientMutationId } }' \
    || warn "auto-merge refused on #$1 (repo has no merge requirement to wait on)"
}

# ------------------------------------------------------------------ workspace

[ "$REPORT_ONLY" = 1 ] && { report; exit 0; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/reviu-fixtures.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
step "cloning $REPO into $WORK"
git clone -q "https://x-access-token:${ME_TOKEN}@github.com/${REPO}.git" "$WORK/repo"
cd "$WORK/repo"
git config user.name "$ME"
git config user.email "$ME_EMAIL"

as_bot() { git -c user.name="$BOT" -c user.email="$BOT_EMAIL" "$@"; }
cut_branch() { git checkout -qB "$1" origin/main; }
push_branch() { git push -q -f origin "$1"; }
head_sha() { git rev-parse HEAD; }

SUMMARY="$WORK/fixtures.tsv"
: > "$SUMMARY"
record() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$SUMMARY"; echo "  -> #$2  $3"; }

# ---------------------------------------------------------------------- purge

step "purging previous fx/* fixtures"
gh_me pr list --repo "$REPO" --state open --limit 200 --json number,headRefName \
  -q '.[] | select(.headRefName | startswith("fx/")) | "\(.number) \(.headRefName)"' \
  | while read -r n b; do
      purge_match "$b" && gh_me pr close --repo "$REPO" "$n" >/dev/null 2>&1 || true
    done
for b in $(gh_me api "repos/$REPO/branches" --paginate -q '.[].name' | grep '^fx/' || true); do
  purge_match "$b" || continue
  gh_me api -X DELETE "repos/$REPO/git/refs/heads/$b" --silent 2>/dev/null && echo "  deleted $b" || true
done
if gh_bot api "repos/$BOT/$NAME" --silent >/dev/null 2>&1; then
  for b in $(gh_bot api "repos/$BOT/$NAME/branches" --paginate -q '.[].name' | grep '^fx/' || true); do
    purge_match "$b" || continue
    gh_bot api -X DELETE "repos/$BOT/$NAME/git/refs/heads/$b" --silent 2>/dev/null || true
  done
fi
[ "$PURGE_ONLY" = 1 ] && { echo "purge done"; exit 0; }

ensure_collaborator
gh_me api -X PATCH "repos/$REPO" -F allow_auto_merge=true --silent >/dev/null 2>&1 || true

# ------------------------------------------------------------------- fixtures

if wants 01; then
  step "01 open + mergeable + review requested + green checks"
  cut_branch fx/01-ready
  cat > src/services/cache.ts <<'F'
export interface CacheEntry<T> {
  value: T
  expiresAt: number
}

export class MemoryCache<T> {
  private entries = new Map<string, CacheEntry<T>>()

  get(key: string): T | undefined {
    const entry = this.entries.get(key)
    if (!entry) return undefined
    if (entry.expiresAt < Date.now()) {
      this.entries.delete(key)
      return undefined
    }
    return entry.value
  }

  set(key: string, value: T, ttlMs: number): void {
    this.entries.set(key, { value, expiresAt: Date.now() + ttlMs })
  }
}
F
  git add src/services/cache.ts
  as_bot commit -qm "feat(cache): add an in-memory cache with TTL"
  push_branch fx/01-ready
  SHA=$(head_sha)
  N=$(pr_new bot fx/01-ready main "feat(cache): in-memory cache with TTL" \
    "Small, clean, mergeable. Baseline fixture for the happy path.")
  gh_me api -X POST "repos/$REPO/pulls/$N/requested_reviewers" -f "reviewers[]=$ME" --silent
  gh_me api -X POST "repos/$REPO/issues/$N/assignees" -f "assignees[]=$ME" --silent
  status_set "$SHA" success ci/lint "no issues"
  status_set "$SHA" success ci/test "42 passed"
  status_set "$SHA" success ci/build "built in 12s"
  record 01 "$N" "open, mergeable, review requested from you, 3 green statuses"
fi

if wants 02; then
  step "02 conflicting (not mergeable)"
  cut_branch fx/02-conflict
  cat > feature-a.txt <<'F'
feature A rewritten on the branch
branch line two
branch line three
branch line four
branch line five
F
  git add feature-a.txt
  as_bot commit -qm "refactor(feature-a): rewrite the whole file on the branch"
  push_branch fx/02-conflict
  N=$(pr_new bot fx/02-conflict main "refactor(feature-a): rewrite the file" \
    "Deliberately conflicts with main. Merge must be blocked with a conflict.")
  git fetch -q origin main
  git checkout -q -B main origin/main
  cat > feature-a.txt <<'F'
feature A rewritten on main
main line two
main line three
main line four
main line five
F
  git add feature-a.txt
  git commit -qm "refactor(feature-a): rewrite the file on main"
  git push -q origin main
  record 02 "$N" "open, CONFLICTING against main"
fi

if wants 03; then
  step "03 draft with failing checks"
  cut_branch fx/03-draft
  printf '\nexport const EXPERIMENTAL_FLAGS = ["dark-mode", "beta-search"]\n' >> src/api/config.ts
  git add src/api/config.ts
  as_bot commit -qm "feat(config): add experimental flags"
  push_branch fx/03-draft
  SHA=$(head_sha)
  N=$(pr_new bot fx/03-draft main "feat(config): experimental flags" \
    "Work in progress. Draft + red CI." --draft)
  status_set "$SHA" failure ci/test "3 failed, 39 passed"
  status_set "$SHA" success ci/lint "no issues"
  status_set "$SHA" error ci/deploy "runner exploded"
  record 03 "$N" "DRAFT, 1 failure + 1 error status"
fi

if wants 04; then
  step "04 closed draft"
  cut_branch fx/04-closed
  printf '\n// abandoned spike\n' >> src/main.ts
  git add src/main.ts
  as_bot commit -qm "spike: try a different bootstrap"
  push_branch fx/04-closed
  N=$(pr_new bot fx/04-closed main "spike: different bootstrap" \
    "Abandoned. Closed while still a draft, so Reviu must show Closed, not Draft." --draft)
  gh_bot api -X PATCH "repos/$REPO/pulls/$N" -f state=closed --silent
  record 04 "$N" "CLOSED while draft (status precedence check)"
fi

if wants 05; then
  step "05 merged"
  cut_branch fx/05-merged
  printf '\nexport const BUILD_CHANNEL = "stable"\n' >> src/version.ts
  git add src/version.ts
  as_bot commit -qm "chore(version): declare the build channel"
  push_branch fx/05-merged
  N=$(pr_new bot fx/05-merged main "chore(version): declare the build channel" \
    "Merged fixture.")
  gh_me api -X PUT "repos/$REPO/pulls/$N/merge" -f merge_method=squash --silent
  record 05 "$N" "MERGED (squash)"
fi

if wants 06; then
  step "06 approved by the bot, plus a dismissed review"
  cut_branch fx/06-approved
  printf '\nexport function formatBytes(n: number): string {\n  const units = ["B", "kB", "MB", "GB"]\n  let i = 0\n  while (n >= 1024 && i < units.length - 1) {\n    n /= 1024\n    i++\n  }\n  return `${n.toFixed(1)} ${units[i]}`\n}\n' >> src/services/settings.ts
  git add src/services/settings.ts
  git commit -qm "feat(settings): add a byte formatter"
  push_branch fx/06-approved
  SHA=$(head_sha)
  N=$(pr_new me fx/06-approved main "feat(settings): byte formatter" \
    "Authored by you so the bot can review it.")
  gh_bot api "repos/$REPO/issues/$N/comments" -f body="Nice, this drops the duplicated formatting in three call sites." --silent
  OLD=$(gh_bot api "repos/$REPO/pulls/$N/reviews" -f event=APPROVE -f body="Approved, then dismissed on purpose." -f commit_id="$SHA" -q .id)
  gh_me api -X PUT "repos/$REPO/pulls/$N/reviews/$OLD/dismissals" -f message="Dismissed: the formatter changed since." -f event=DISMISS --silent
  gh_bot api "repos/$REPO/pulls/$N/reviews" -f event=APPROVE -f body="Re-approved. Ship it." -f commit_id="$SHA" --silent
  record 06 "$N" "open, 1 DISMISSED + 1 APPROVED review, 1 issue comment"
fi

if wants 07; then
  step "07 changes requested with inline comments"
  cut_branch fx/07-changes
  cat > src/services/retry.ts <<'F'
export async function retry<T>(fn: () => Promise<T>, attempts: number): Promise<T> {
  let lastError: unknown
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn()
    } catch (error) {
      lastError = error
    }
  }
  throw lastError
}

export function backoff(attempt: number): number {
  return attempt * 1000
}
F
  git add src/services/retry.ts
  git commit -qm "feat(retry): add a retry helper"
  push_branch fx/07-changes
  SHA=$(head_sha)
  N=$(pr_new me fx/07-changes main "feat(retry): retry helper" \
    "Authored by you. The bot requests changes with three inline comments.")
  cat > "$WORK/review-07.json" <<'F'
{
  "event": "REQUEST_CHANGES",
  "commit_id": "__SHA__",
  "body": "A few things before this lands.",
  "comments": [
    { "path": "src/services/retry.ts", "line": 1, "side": "RIGHT",
      "body": "`attempts` is never validated: `retry(fn, 0)` throws `undefined`." },
    { "path": "src/services/retry.ts", "start_line": 3, "line": 10, "start_side": "RIGHT", "side": "RIGHT",
      "body": "Multi-line anchor. The loop swallows every error but the last one. Consider an `AggregateError`." },
    { "path": "src/services/retry.ts", "line": 14, "side": "RIGHT",
      "body": "Retrying with no delay hammers the server.\n\n```suggestion\nexport function backoff(attempt: number): number {\n  return Math.min(2 ** attempt * 100, 30_000)\n}\n```" }
  ]
}
F
  sed -i "s/__SHA__/$SHA/" "$WORK/review-07.json"
  gh_bot api "repos/$REPO/pulls/$N/reviews" --input "$WORK/review-07.json" --silent
  status_set "$SHA" failure ci/test "retry.test.ts: 2 failed"
  record 07 "$N" "open, CHANGES_REQUESTED, 3 inline comments (single, multi-line, suggestion)"
fi

if wants 08; then
  step "08 threads: resolved, unresolved, outdated, reply chain, your pending review"
  cut_branch fx/08-threads
  cat > src/api/rate_limit.ts <<'F'
const WINDOW_MS = 60_000

export class RateLimiter {
  private hits: number[] = []

  allow(limit: number): boolean {
    const now = Date.now()
    this.hits = this.hits.filter((t) => now - t < WINDOW_MS)
    if (this.hits.length >= limit) return false
    this.hits.push(now)
    return true
  }
}
F
  git add src/api/rate_limit.ts
  as_bot commit -qm "feat(api): add a sliding-window rate limiter"
  push_branch fx/08-threads
  SHA=$(head_sha)
  N=$(pr_new bot fx/08-threads main "feat(api): sliding-window rate limiter" \
    "Comment threads in every state.")

  C1=$(gh_me api "repos/$REPO/pulls/$N/comments" -f path=src/api/rate_limit.ts -F line=1 -f side=RIGHT \
        -f commit_id="$SHA" -f body="Why 60s? Worth a constant with a comment." -q .id)
  gh_bot api "repos/$REPO/pulls/$N/comments/$C1/replies" -f body="It matches the upstream API window." --silent
  gh_me  api "repos/$REPO/pulls/$N/comments/$C1/replies" -f body="Then say so in the code, not here." --silent

  gh_me api "repos/$REPO/pulls/$N/comments" -f path=src/api/rate_limit.ts -F line=11 -f side=RIGHT \
    -f commit_id="$SHA" -f body="This one gets resolved." --silent
  gh_me api "repos/$REPO/pulls/$N/comments" -f path=src/api/rate_limit.ts -F line=9 -f side=RIGHT \
    -f commit_id="$SHA" -f body="This one goes outdated once the file moves." --silent

  # Resolve exactly one thread, then push a commit that shifts the anchors so the rest go outdated.
  FIRST=$(thread_ids "$N" | sed -n '2p')
  [ -n "$FIRST" ] && resolve_thread "$FIRST"

  sed -i '1i // Sliding window, sized to match the upstream quota refill.\n' src/api/rate_limit.ts
  sed -i 's|^    if (this.hits.length >= limit) return false$|    if (this.hits.length >= limit) {\n      return false\n    }|' src/api/rate_limit.ts
  printf '\nexport const DEFAULT_LIMIT = 100\n' >> src/api/rate_limit.ts
  git add src/api/rate_limit.ts
  as_bot commit -qm "docs(api): explain the window and expose a default limit"
  push_branch fx/08-threads
  NEWSHA=$(head_sha)

  cat > "$WORK/pending-08.json" <<'F'
{
  "commit_id": "__SHA__",
  "body": "Pending review, never submitted. Reviu should show it as a draft.",
  "comments": [
    { "path": "src/api/rate_limit.ts", "line": 5, "side": "RIGHT", "body": "Unsubmitted pending comment." }
  ]
}
F
  sed -i "s/__SHA__/$NEWSHA/" "$WORK/pending-08.json"
  gh_me api "repos/$REPO/pulls/$N/reviews" --input "$WORK/pending-08.json" --silent
  status_set "$NEWSHA" pending ci/test "running"
  record 08 "$N" "open, resolved + unresolved + outdated threads, reply chain, your PENDING review"
fi

if wants 09; then
  step "09 full check rollup"
  cut_branch fx/09-checks
  printf '\nexport const TELEMETRY_ENDPOINT = "https://telemetry.example.com/v2"\n' >> src/services/analytics.ts
  git add src/services/analytics.ts
  as_bot commit -qm "feat(analytics): point telemetry at v2"
  push_branch fx/09-checks
  SHA=$(head_sha)
  N=$(pr_new bot fx/09-checks main "feat(analytics): telemetry v2" \
    "Every check state at once: success, failure, pending, error.")
  status_set "$SHA" success ci/lint "clean"
  status_set "$SHA" success ci/typecheck "no errors"
  status_set "$SHA" failure ci/test "1 failed"
  status_set "$SHA" pending ci/e2e "queued"
  status_set "$SHA" error ci/security "scanner unavailable"
  status_set "$SHA" success codecov/patch "92% of diff covered"
  record 09 "$N" "open, 6 statuses covering every rollup state"
fi

if wants 10; then
  step "10 heavy diff: rename, delete, add, binary, huge patch"
  cut_branch fx/10-bigdiff
  git mv src/components/Badge.vue src/components/StatusBadge.vue
  git rm -q src/components/Spinner.vue
  cp "Screenshot 2026-04-08 at 18.43.19.png" public/hero.png
  cat > src/components/StatusPill.vue <<'F'
<script setup lang="ts">
defineProps<{ label: string; tone: 'ok' | 'warn' | 'error' }>()
</script>

<template>
  <span class="status-pill" :class="`status-pill--${tone}`">{{ label }}</span>
</template>
F
  sed -i '1,3000s/^export const /export let /' perf-50k.ts
  git add -A
  as_bot commit -qm "refactor(ui): rename Badge, drop Spinner, add StatusPill"
  push_branch fx/10-bigdiff
  N=$(pr_new bot fx/10-bigdiff main "refactor(ui): badge rename and pill component" \
    "Rename + delete + add + binary + a patch large enough that GitHub truncates it.")
  record 10 "$N" "open, renamed/deleted/added/binary files + truncated huge patch"
fi

if wants 11; then
  step "11 PR from the bot's fork"
  gh_bot repo fork "$REPO" --clone=false --default-branch-only >/dev/null 2>&1 || true
  FORK_URL="https://x-access-token:${BOT_TOKEN}@github.com/${BOT}/${NAME}.git"
  FORK_READY=0
  for _ in $(seq 1 30); do
    if git ls-remote --exit-code "$FORK_URL" >/dev/null 2>&1; then FORK_READY=1; break; fi
    sleep 2
  done
  if [ "$FORK_READY" = 1 ]; then
    cut_branch fx/11-fork
    printf '\n// contributed from a fork\nexport const CONTRIBUTED = true\n' >> src/api/client.ts
    git add src/api/client.ts
    as_bot commit -qm "feat(client): flag fork-contributed builds"
    git push -q -f "$FORK_URL" fx/11-fork
    N=$(pr_new bot "$BOT:fx/11-fork" main "feat(client): fork-contributed flag" \
      "Head repository differs from the base repository.")
    record 11 "$N" "open, head_repository = $BOT/$NAME (fork)"
  else
    warn "fork $BOT/$NAME never became reachable; skipping 11"
  fi
fi

if wants 12; then
  step "12 auto-merge armed"
  cut_branch fx/12-automerge
  printf '\nexport const AUTO_MERGE_DEMO = 1\n' >> src/version.ts
  git add src/version.ts
  as_bot commit -qm "chore: arm auto-merge on this branch"
  push_branch fx/12-automerge
  SHA=$(head_sha)
  N=$(pr_new bot fx/12-automerge main "chore: auto-merge fixture" \
    "Auto-merge is enabled and waiting." --draft)
  status_set "$SHA" pending ci/required "waiting for the runner"
  enable_automerge "$N"
  record 12 "$N" "draft, auto-merge armed (squash), pending required status"
fi

if wants 13; then
  step "13 rich GFM body and conversation"
  cut_branch fx/13-gfm
  printf '\n<!-- gfm fixture -->\n' >> README.md
  git add README.md
  as_bot commit -qm "docs: mark the GFM fixture branch"
  push_branch fx/13-gfm
  BODY=$(cat <<'F'
## What this does

Exercises every GFM construct the markdown viewer has to render.

| Surface | Before | After |
| --- | ---: | :---: |
| Inbox | 120ms | **38ms** |
| Diff | 400ms | `210ms` |

- [x] tables
- [x] task lists
- [ ] footnotes

> Blockquote with `inline code`, a [link](https://github.com), and ~~strikethrough~~.

```rust
fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
    div().child("hello")
}
```

<details>
<summary>Collapsed section</summary>

Hidden until expanded. Contains a nested list:

1. one
2. two
   - nested
</details>

Public image: ![octocat](https://github.githubassets.com/images/modules/logos_page/Octocat.png)

Private raw image (needs the app to resolve the asset URL):
![favicon](https://raw.githubusercontent.com/joris-gallot/git-playground/main/public/favicon.ico)

---

Mentions @joris-gallot and a cross-reference to #1.
F
)
  N=$(pr_new bot fx/13-gfm main "docs: GFM rendering fixture" "$BODY")
  gh_bot api "repos/$REPO/issues/$N/comments" -f body='Follow-up with a mermaid block:

```mermaid
graph TD
  A[Session] --> B{Has diff?}
  B -->|yes| C[Diff view]
  B -->|no| D[Conversation]
```' --silent
  gh_me api "repos/$REPO/issues/$N/comments" -f body="Long paragraph to test wrapping. $(head -c 600 /dev/zero | tr '\0' 'x' | fold -w 40 | tr '\n' ' ')" --silent
  record 13 "$N" "open, rich GFM body + mermaid + long comment"
fi

if wants 14; then
  step "14 stacked PR (base is not main)"
  cut_branch fx/14-base
  printf '\nexport interface Plugin { name: string; setup(): void }\n' >> src/main.ts
  git add src/main.ts
  as_bot commit -qm "feat(plugins): declare the plugin interface"
  push_branch fx/14-base
  BASE_N=$(pr_new bot fx/14-base main "feat(plugins): plugin interface" "Bottom of the stack.")
  git checkout -qB fx/14-stacked fx/14-base
  printf '\nexport const BUILTIN_PLUGINS: Plugin[] = []\n' >> src/main.ts
  git add src/main.ts
  as_bot commit -qm "feat(plugins): register the builtin plugin list"
  push_branch fx/14-stacked
  N=$(pr_new bot fx/14-stacked fx/14-base "feat(plugins): builtin plugin registry" \
    "Stacked on top of the plugin interface PR.")
  record 14 "$BASE_N" "open, bottom of a stack"
  record 14 "$N" "open, base = fx/14-base (not main)"
fi

if [ "$WITH_ACTIONS" = 1 ]; then
  step "pushing the real Actions workflow (burns runner minutes)"
  git fetch -q origin main
  git checkout -q -B main origin/main
  mkdir -p .github/workflows
  cat > .github/workflows/fx-checks.yml <<'F'
name: fx-checks
on:
  pull_request:
    branches: [main]

jobs:
  passing:
    runs-on: ubuntu-latest
    steps:
      - run: echo "step one"
      - run: echo "step two"
      - run: echo "step three"
  failing:
    runs-on: ubuntu-latest
    steps:
      - run: echo "about to fail"
      - run: exit 1
  skipped:
    if: false
    runs-on: ubuntu-latest
    steps:
      - run: echo "never runs"
F
  git add .github/workflows/fx-checks.yml
  git commit -qm "ci: add the fixture workflow"
  git push -q origin main
  echo "  workflow pushed; reopen an fx/ PR to trigger a run"
fi

# --------------------------------------------------------------------- report

report
