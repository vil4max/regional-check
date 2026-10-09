# Local artifact lifecycle

## Decision

Evidence produced while working on the app belongs to this project. All linked
worktrees use the primary checkout's ignored `.artifacts/<task-slug>/`, resolved
from Git metadata rather than a guessed sibling path. This survives removal of a
completed task worktree.

Tracked specifications, decisions, required test fixtures, and approved design
assets remain in their existing directories. Screenshots, videos, coverage
reports, diagnostic logs, and temporary investigation outputs stay local.
Ignored storage is neither a backup nor a security boundary: do not use
`git clean -fdx` on the primary checkout, delete that checkout, or force-add
artifacts. Preserve valuable evidence before replacing the primary clone.

## Commands

From an updated checkout or worktree:

```bash
python3 scripts/project-artifacts.py root
python3 scripts/project-artifacts.py task rd-13-recapture
```

`root` is read-only. `task` creates a shared directory, refuses traversal and
symlinks, and requires the primary checkout to ignore `.artifacts/`. Use a unique
task slug; parallel runs must use distinct filenames or subdirectories. Record the
task, tested commit, command, and relevant environment beside outputs. Do not store
credentials, personal data, or private exports here.

Existing worktrees may predate these commands. They can invoke the primary
checkout's helper without switching branches or copying project code:

```bash
common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
python3 "$common_dir/../scripts/project-artifacts.py" task rd-13-recapture
```

This fallback is for the project's ordinary primary checkout with a `.git`
directory. The helper itself resolves the primary checkout from `git worktree
list` and verifies repository identity. An unavailable primary checkout is a
failure: preserve the current files and do not remove their worktree.

## Cleanup contract

Use the primary checkout's `scripts/prune-worktrees.sh`; never bypass it with
forced removal. Its clean-tree and landed-commit guards stay in force. Before
removing an eligible worktree, the artifact guard also blocks on nonempty or
symlinked `.artifacts/` and unclassified ignored files.

Only reproducible build caches (`DerivedData`, `.screenshot-derived`, `build`,
`.build`, `.swiftpm`) and exact local setup files
listed in `scripts/project-artifacts.py` are exempt. Do not put evidence in these
cache locations; export it to the shared artifacts directory first.

When blocked, copy unique evidence to the shared task directory, compare file
hashes, and record provenance. Remove local duplicates only after verifying the
copy and confirming that nothing still writes them. Rerun cleanup afterwards.
The guard does not infer durability or silently archive arbitrary ignored data.

## Verification

Run `python3 scripts/tests/project-artifacts-contract.py`. Fixtures use temporary
Git repositories and a local bare remote; they never build the app, access the
network, or prune real worktrees. The contract covers shared path resolution,
creation, invalid paths, preservation of ignored evidence, and safe cleanup.
