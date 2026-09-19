#!/usr/bin/env python3
"""Resolve shared project evidence and refuse unsafe worktree cleanup."""
import argparse
from pathlib import Path
import re
import subprocess


def git(path, *args):
    return subprocess.check_output(['git', '-C', str(path), *args])


def primary(path):
    records = git(path, 'worktree', 'list', '--porcelain', '-z').split(b'\0')
    first = next(x for x in records if x.startswith(b'worktree '))
    root = Path(first[9:].decode()).resolve()
    if not root.is_dir() or git(root, 'rev-parse', '--is-bare-repository').strip() != b'false':
        raise ValueError('Primary checkout unavailable; preserve the worktree')
    if git(root, 'rev-parse', '--path-format=absolute', '--git-common-dir') != git(path, 'rev-parse', '--path-format=absolute', '--git-common-dir'):
        raise ValueError('Primary checkout belongs to another repository')
    return root


def artifact_root(path):
    root = primary(path) / '.artifacts'
    if root.is_symlink():
        raise ValueError('Artifacts root must not be a symlink')
    return root


def check_worktree(path):
    # Only reproducible caches and exact local setup files may be discarded.
    prefixes = ('DerivedData/', '.screenshot-derived/', 'build/', '.build/', '.swiftpm/',
                'Tooling/backend/build/')
    files = {'.DS_Store', 'Tooling/runtime.local.yml', 'runtime.local.yml',
             '.agents/project-context.yaml', '.cursor/project-context',
             '.cursor/project-context.yaml'}
    ignored = git(path, 'ls-files', '--others', '--ignored', '--exclude-standard', '-z')
    unsafe = [x.decode() for x in ignored.split(b'\0') if x and
              x.decode() not in files and not x.decode().startswith(prefixes)]
    artifacts = Path(path) / '.artifacts'
    if artifacts.is_symlink() or (artifacts.exists() and any(artifacts.iterdir())):
        unsafe.append('.artifacts/ (preserve outside this worktree)')
    if unsafe:
        print('KEEP: review and preserve ignored evidence before cleanup:')
        for name in sorted(set(unsafe)):
            print('  ' + name)
        return 1
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('root')
    task = sub.add_parser('task')
    task.add_argument('slug')
    check = sub.add_parser('check-worktree')
    check.add_argument('path', type=Path)
    args = parser.parse_args()
    if args.command == 'check-worktree':
        return check_worktree(args.path)
    root = artifact_root(Path.cwd())
    if args.command == 'task':
        if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', args.slug):
            raise ValueError('Use a lowercase task slug with digits and hyphens')
        root = root / args.slug
        if root.is_symlink():
            raise ValueError('Task directory must not be a symlink')
        parent = primary(Path.cwd())
        probe = subprocess.run(['git', '-C', str(parent), 'check-ignore', '-q', '.artifacts/probe'])
        if probe.returncode:
            raise ValueError('Primary checkout must ignore /.artifacts/ before use')
        root.mkdir(parents=True, exist_ok=True)
    print(root)
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error))
