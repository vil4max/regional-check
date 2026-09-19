#!/usr/bin/env python3
"""Exercise artifact routing and real cleanup using disposable repositories."""
from pathlib import Path
import shutil
import subprocess
import tempfile

SOURCE = Path(__file__).resolve().parents[1]


def run(path, *args, ok=True):
    result = subprocess.run(args, cwd=path, text=True, capture_output=True)
    if ok and result.returncode:
        raise AssertionError(result.stderr + result.stdout)
    return result


with tempfile.TemporaryDirectory(prefix='artifact-contract-') as tmp:
    base = Path(tmp).resolve()
    repo = base / 'primary checkout'
    repo.mkdir()
    run(repo, 'git', 'init', '-q', '-b', 'main')
    run(repo, 'git', 'config', 'user.name', 'Fixture')
    run(repo, 'git', 'config', 'user.email', 'fixture@example.invalid')
    run(repo, 'git', 'config', 'core.hooksPath', '/dev/null')
    (repo / 'scripts').mkdir()
    for name in ['project-artifacts.py', 'prune-worktrees.sh']:
        shutil.copy2(SOURCE / name, repo / 'scripts' / name)
    (repo / '.gitignore').write_text('/.artifacts/\n/local-output/\n/build/\n')
    run(repo, 'git', 'add', '.')
    run(repo, 'git', 'commit', '-qm', 'chore: initialize fixture')
    run(base, 'git', 'init', '--bare', '-q', str(base / 'remote.git'))
    run(repo, 'git', 'remote', 'add', 'origin', str(base / 'remote.git'))
    run(repo, 'git', 'push', '-qu', 'origin', 'main')
    wt = base / 'task checkout'
    run(repo, 'git', 'worktree', 'add', '-qb', 'task', str(wt))
    helper = str(repo / 'scripts/project-artifacts.py')
    expected = str(repo / '.artifacts')
    assert run(wt, 'python3', helper, 'root').stdout.strip() == expected
    assert not (repo / '.artifacts').exists()
    destination = Path(run(wt, 'python3', helper, 'task', 'rd-13').stdout.strip())
    assert destination == repo / '.artifacts/rd-13' and destination.is_dir()
    (destination / 'proof.txt').write_text('preserve')
    assert run(wt, 'python3', helper, 'task', '../escape', ok=False).returncode
    (repo / '.artifacts/link').symlink_to(base, target_is_directory=True)
    assert run(wt, 'python3', helper, 'task', 'link', ok=False).returncode
    (wt / 'change.txt').write_text('task change')
    run(wt, 'git', 'add', 'change.txt')
    run(wt, 'git', 'commit', '-qm', 'docs: add fixture evidence')
    run(repo, 'git', 'merge', '--ff-only', 'task')
    (wt / '.artifacts').mkdir()
    (wt / '.artifacts/unique.txt').write_text('unique')
    prune = str(repo / 'scripts/prune-worktrees.sh')
    result = run(repo, 'bash', prune, '--apply', '--only', 'task')
    assert wt.exists() and 'local evidence requires preservation' in result.stdout
    shutil.move(wt / '.artifacts/unique.txt', destination / 'unique.txt')
    (wt / 'local-output').mkdir()
    (wt / 'local-output/log.txt').write_text('unknown ignored output')
    result = run(repo, 'bash', prune, '--apply', '--only', 'task')
    assert wt.exists() and 'local evidence requires preservation' in result.stdout
    shutil.move(wt / 'local-output/log.txt', destination / 'log.txt')
    (wt / 'build').mkdir()
    (wt / 'build/cache.txt').write_text('reproducible')
    run(repo, 'bash', prune, '--apply', '--only', 'task')
    assert not wt.exists()
    assert (destination / 'unique.txt').read_text() == 'unique'
    assert (destination / 'proof.txt').read_text() == 'preserve'
print('Project artifact contracts: PASS')
