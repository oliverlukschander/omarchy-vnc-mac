#!/usr/bin/python3
"""Descriptor-relative, no-follow reads/writes for user config files."""

from __future__ import annotations

import os
import stat
import sys
from pathlib import Path

MAX_BYTES = 1_048_576


def die(msg: str) -> None:
    raise SystemExit(msg)


def _owned_by_us(st: os.stat_result) -> bool:
    return st.st_uid == os.getuid()


def _parent_dirfd(path: Path, *, create: bool) -> int:
    parent = path.parent
    if create:
        parent.mkdir(parents=True, exist_ok=True)
    try:
        dirfd = os.open(parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    except OSError as exc:
        die(f"refusing parent {parent}: {exc}")
    st = os.fstat(dirfd)
    if not stat.S_ISDIR(st.st_mode):
        os.close(dirfd)
        die(f"parent is not a directory: {parent}")
    if not _owned_by_us(st):
        os.close(dirfd)
        die(f"parent not owned by current user: {parent}")
    return dirfd


def read_text(path: Path, *, missing: str | None = None) -> str:
    parent = path.parent
    try:
        dirfd = os.open(parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    except FileNotFoundError:
        if missing is not None:
            return missing
        die(f"missing {path}")
    except OSError as exc:
        die(f"refusing parent {parent}: {exc}")
    st = os.fstat(dirfd)
    if not stat.S_ISDIR(st.st_mode) or not _owned_by_us(st):
        os.close(dirfd)
        die(f"refusing parent {parent}")
    try:
        try:
            fd = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=dirfd)
        except FileNotFoundError:
            if missing is not None:
                return missing
            die(f"missing {path}")
        except OSError as exc:
            die(f"refusing to read {path}: {exc}")
        try:
            st = os.fstat(fd)
            if not stat.S_ISREG(st.st_mode):
                die(f"refusing non-regular file: {path}")
            if not _owned_by_us(st):
                die(f"file not owned by current user: {path}")
            if st.st_size > MAX_BYTES:
                die(f"file too large ({st.st_size} bytes): {path}")
            data = os.read(fd, MAX_BYTES + 1)
            if len(data) > MAX_BYTES:
                die(f"file too large: {path}")
            return data.decode()
        finally:
            os.close(fd)
    finally:
        os.close(dirfd)


def atomic_write(path: Path, text: str) -> None:
    data = text.encode()
    if len(data) > MAX_BYTES:
        die(f"refusing to write oversized file: {path}")
    dirfd = _parent_dirfd(path, create=True)
    tmp = f".{path.name}.{os.getpid()}.tmp"
    fd = -1
    try:
        try:
            existing = os.stat(path.name, dir_fd=dirfd, follow_symlinks=False)
        except FileNotFoundError:
            existing = None
        if existing is not None:
            if stat.S_ISLNK(existing.st_mode) or not stat.S_ISREG(existing.st_mode):
                die(f"refusing non-regular file: {path}")
            if not _owned_by_us(existing):
                die(f"file not owned by current user: {path}")
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW
        fd = os.open(tmp, flags, 0o600, dir_fd=dirfd)
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode) or not _owned_by_us(st):
            die(f"refusing temp file {tmp}")
        written = 0
        while written < len(data):
            written += os.write(fd, data[written:])
        os.fsync(fd)
        os.close(fd)
        fd = -1
        os.rename(tmp, path.name, src_dir_fd=dirfd, dst_dir_fd=dirfd)
        landed = os.stat(path.name, dir_fd=dirfd, follow_symlinks=False)
        if stat.S_ISLNK(landed.st_mode) or not stat.S_ISREG(landed.st_mode):
            die(f"rename did not land on a regular file: {path}")
        if not _owned_by_us(landed):
            die(f"renamed file not owned by current user: {path}")
    except Exception:
        if fd >= 0:
            os.close(fd)
        try:
            os.unlink(tmp, dir_fd=dirfd)
        except FileNotFoundError:
            pass
        except OSError:
            pass
        raise
    finally:
        os.close(dirfd)


def copy_file(src: Path, dst: Path) -> None:
    atomic_write(dst, read_text(src))


def remove_file(path: Path) -> None:
    try:
        dirfd = _parent_dirfd(path, create=False)
    except SystemExit:
        return
    try:
        try:
            st = os.stat(path.name, dir_fd=dirfd, follow_symlinks=False)
        except FileNotFoundError:
            return
        if stat.S_ISLNK(st.st_mode) or not stat.S_ISREG(st.st_mode):
            die(f"refusing non-regular file: {path}")
        if not _owned_by_us(st):
            die(f"file not owned by current user: {path}")
        os.unlink(path.name, dir_fd=dirfd)
    finally:
        os.close(dirfd)


def main(argv: list[str]) -> None:
    if len(argv) < 2:
        die("usage: safe_file.py copy SRC DST | remove PATH")
    action = argv[1]
    if action == "copy" and len(argv) == 4:
        copy_file(Path(argv[2]), Path(argv[3]))
    elif action == "remove" and len(argv) == 3:
        remove_file(Path(argv[2]))
    else:
        die("usage: safe_file.py copy SRC DST | remove PATH")


if __name__ == "__main__":
    main(sys.argv)
