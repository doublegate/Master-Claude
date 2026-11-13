#!/usr/bin/env python3
"""skillspector-gate: scan an agent skill with SkillSpector before an agent installs it.

A PreToolUse hook for Claude Code, Codex CLI and Antigravity (agy). It recognises shell
commands that install a skill into an agent skills directory, scans every skill they
would install, and only stays out of the way when SkillSpector says the skill is safe.

  skillspector-gate.py hook --agent claude|codex|agy    (stdin: the hook payload)
  skillspector-gate.py post --agent claude|codex|agy    (PostToolUse: verify the install)
  skillspector-gate.py approve <target> [--skill NAME]  (human only: accept a verdict)
  skillspector-gate.py check <target> [--skill NAME]    (run the gate by hand)

Recognised installs (per shell sub-command, `cd` tracked across a chain):
  git clone <url> <dest-in-skills-dir>
  cp / mv / rsync / ln <src>... <dest-in-skills-dir>
  unzip <zip> -d <dest-in-skills-dir>, tar -x... -f <archive> -C <dest-in-skills-dir>
  npx|bunx|pnpx skills add <owner/repo|url|path> [--skill NAME]  (also pnpm dlx, npm exec)
A skills dir is any path with a `skills` component below .claude/.codex/.agents/.gemini
(and a few other agent homes). MCP servers installed from a package (uvx, npx) carry no
skill bundle, so SkillSpector cannot scan them and this gate does not cover them.
Options are read in every form the tools accept (`--branch=x`, `-bx`, `-rt DIR`), with
per-tool option sets (rsync's -t/-S take no value). `git -C` moves only git, not the
shell's tracked cwd. Local `skills add` paths resolve against that tracked cwd. Sources
already in a skills dir are scanned too (an installed skill may have been edited since),
and archives are refused before extraction when their declared size or member count
exceeds the limits.

Verdicts: safe_to_install -> pass. DO_NOT_INSTALL -> deny, and final: no later target or
error weakens it. Anything else (CAUTION, partial coverage, LLM pass missing, a target
that cannot be scanned) -> ask; Codex has no `ask`, so deny.
Results are cached by content hash. `approve` records a content hash a human accepted;
agent tool calls that try to approve, or touch the approvals file or the verdict cache, are
denied, including a read command whose output is redirected. `ln` into a skills dir asks:
a link follows its source, so no scan binds to it. Also asked rather than passed: an
install whose path the shell expands (glob, variable, substitution) while anything in the
chain names a skills dir or agent home, and an install chained with any step other than
cd/mkdir/ls/pwd/test, since those steps run after the scan.

Known gaps. This is a policy guard over the command TEXT, not a sandbox: an agent set on
evading it (an interpreter writing a file under an assembled name) can still reach the
protected files; only an approvals store the agent's user cannot write (root-owned, or
signed with a key it cannot read) would close that.

Remote installs are verified after the fact. For git and `skills add` the gate scans its
own clone and the agent's command fetches again, so a remote serving different content per
request could install bytes the gate never saw. The pre-install hook therefore records the
scanned digest of every skill, keyed by the exact command, in gate-pending.json (protected
like the approvals file). The `post` hook (PostToolUse) hashes what was actually installed
and, on any mismatch, moves the install into the gate's quarantine directory and tells the
agent. A `skills add` destination is chosen by that CLI, so the post hook looks for the
skill by name in the agent skills dirs; if it cannot find it, it reports the install as
unverified rather than claiming it matched.
"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import zipfile
from pathlib import Path

HOME = Path.home()
STATE_DIR = Path(
    os.environ.get("SKILLSPECTOR_GATE_STATE", HOME / ".config" / "skillspector")
)
CACHE_FILE = Path(
    os.environ.get(
        "SKILLSPECTOR_GATE_CACHE",
        HOME / ".cache" / "skillspector-gate" / "verdicts.json",
    )
)
APPROVALS_NAME = "gate-approvals.json"
# Scanned digests of remote installs awaiting post-install verification (see `post`).
PENDING_FILE = CACHE_FILE.parent / "gate-pending.json"
PENDING_TTL = 86400
QUARANTINE_DIR = CACHE_FILE.parent / "quarantine"
SKILLSPECTOR_PY = os.environ.get(
    "SKILLSPECTOR_GATE_PYTHON",
    str(HOME / ".local/share/uv/tools/skillspector/bin/python"),
)
CACHE_TTL = 14 * 86400
PER_SCAN_TIMEOUT = 600
TOTAL_BUDGET = 840  # registered hook timeout is 900 s
MAX_SKILLS = 8
MAX_TREE_BYTES = 200 * 1024 * 1024
# Checked BEFORE extraction (from the archive's own directory), so a small hostile archive
# cannot fill the temp filesystem while the pre-install gate is still evaluating it.
MAX_ARCHIVE_BYTES = MAX_TREE_BYTES
MAX_ARCHIVE_MEMBERS = 10_000

# Defaults matching ~/.config/fish/conf.d/skillspector.fish, for hosts that launch the
# agent without that shell environment.
SCAN_ENV_DEFAULTS = {
    "SKILLSPECTOR_PROVIDER": "claude_cli",
    "SKILLSPECTOR_MODEL": "claude-sonnet-5-5",
    "SKILLSPECTOR_MODEL_META_ANALYZER": "claude-opus-5-5",
    "SKILLSPECTOR_MODEL_REGISTRY": str(
        HOME / ".config/skillspector/model_registry.yaml"
    ),
}

AGENT_HOMES = {
    ".claude",
    ".codex",
    ".agents",
    ".gemini",
    ".opencode",
    ".cursor",
    ".windsurf",
    ".kiro",
    ".hermes",
    ".crush",
    ".pi",
}
KEYWORDS = (
    "clone",
    "cp",
    "mv",
    "rsync",
    "ln",
    "install",
    "unzip",
    "tar",
    "skills",
    "skillspector-gate",
    APPROVALS_NAME,
    CACHE_FILE.name,
)
# Files whose contents decide a verdict. A cached safe_to_install passes a skill without a
# rescan, so the verdict cache needs the same protection as the approvals file: writing
# either one forges a pass.
PROTECTED_NAMES = (APPROVALS_NAME, CACHE_FILE.name, PENDING_FILE.name)
GIT_OPTS_WITH_VALUE = {
    "-b",
    "--branch",
    "-o",
    "--origin",
    "-c",
    "--config",
    "--depth",
    "--reference",
    "--reference-if-able",
    "--separate-git-dir",
    "--template",
    "-j",
    "--jobs",
    "--filter",
    "--shallow-since",
    "--shallow-exclude",
    "-u",
    "--upload-pack",
    "--server-option",
    "--bundle-uri",
}
# Options that take a value, per command family. cp/mv/install/ln share coreutils'
# -t/--target-directory and -S/--suffix; rsync's -t (times) and -S (sparse) take none.
COPY_OPTS_WITH_VALUE = {"-t", "--target-directory", "-S", "--suffix"}
RSYNC_OPTS_WITH_VALUE = {
    "-e",
    "--rsh",
    "-T",
    "--temp-dir",
    "-f",
    "--filter",
    "-B",
    "--block-size",
    "-M",
    "--remote-option",
    "--exclude",
    "--include",
    "--exclude-from",
    "--include-from",
    "--files-from",
    "--partial-dir",
    "--backup-dir",
    "--suffix",
    "--compare-dest",
    "--copy-dest",
    "--link-dest",
    "--chmod",
    "--chown",
    "--log-file",
    "--log-file-format",
    "--out-format",
    "--password-file",
    "--port",
    "--sockopts",
    "--timeout",
    "--contimeout",
    "--bwlimit",
    "--max-size",
    "--min-size",
    "--max-delete",
    "--modify-window",
    "--iconv",
    "--rsync-path",
    "--usermap",
    "--groupmap",
    "--compress-level",
    "--compress-choice",
    "--checksum-choice",
    "--info",
    "--debug",
    "--stop-after",
    "--stop-at",
    "--write-batch",
    "--only-write-batch",
    "--read-batch",
    "--protocol",
}
WRAPPERS = {
    "sudo",
    "doas",
    "command",
    "builtin",
    "exec",
    "nohup",
    "time",
    "nice",
    "env",
    "timeout",
    "stdbuf",
    "noglob",
    "rtk",
}


class GateError(Exception):
    """A failure after an install was recognised: never fail open on these."""


# --- command parsing ----------------------------------------------------------------


def split_chain(command: str) -> list[str]:
    """Split a shell line on && || ; | & and newlines, outside quotes."""
    parts, buf, quote, i = [], [], None, 0
    while i < len(command):
        c = command[i]
        if quote:
            buf.append(c)
            if c == quote:
                quote = None
            elif c == "\\" and quote == '"' and i + 1 < len(command):
                buf.append(command[i + 1])
                i += 1
        elif c in "'\"":
            quote = c
            buf.append(c)
        elif c == "\\" and i + 1 < len(command):
            buf.append(c + command[i + 1])
            i += 1
        elif c in ";|&\n":
            parts.append("".join(buf))
            buf = []
            while i + 1 < len(command) and command[i + 1] in "|&":
                i += 1
        else:
            buf.append(c)
        i += 1
    parts.append("".join(buf))
    return [p.strip() for p in parts if p.strip()]


def words(sub: str) -> list[str]:
    try:
        return shlex.split(sub, comments=True)
    except ValueError:
        return sub.split()


def strip_wrappers(argv: list[str]) -> list[str]:
    """Drop leading VAR=x assignments and wrapper commands (with their options)."""
    i = 0
    while i < len(argv):
        w = argv[i]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w):
            i += 1
            continue
        base = os.path.basename(w)
        if base in WRAPPERS and i + 1 < len(argv):
            i += 1
            if base == "timeout":
                while i < len(argv) and argv[i].startswith("-"):
                    i += 1
                i += 1  # the duration
            elif base == "rtk" and i < len(argv) and argv[i] == "proxy":
                i += 1
            else:
                while i < len(argv) and (argv[i].startswith("-") or "=" in argv[i]):
                    if argv[i] in ("-u", "-n", "-C") and i + 1 < len(argv):
                        i += 1
                    i += 1
            continue
        break
    return argv[i:]


def expand(path: str, cwd: Path) -> Path:
    p = os.path.expandvars(os.path.expanduser(path))
    q = Path(p)
    return q if q.is_absolute() else (cwd / q)


def opaque(raw: str, expanded: Path) -> bool:
    """True when the shell, not this parser, decides where `raw` points: a glob, a brace
    or command substitution, or a variable the hook's environment could not expand (for
    example one assigned earlier in the same chain)."""
    return bool(re.search(r"[*?\[{`]|\$\(", raw)) or "$" in str(expanded)


# Steps that cannot change a scanned source, a git config or a remote, so they may
# precede an install in one chain without forcing a re-ask.
BENIGN_IN_CHAIN = {"cd", "mkdir", "ls", "pwd", "true", "test", "["}
INSTALL_CMDS = {"git", "cp", "mv", "rsync", "ln", "install", "unzip", "tar", "bsdtar"}


def in_skills_dir(path: Path) -> bool:
    parts = Path(os.path.normpath(path)).parts
    for i, part in enumerate(parts):
        if part == "skills" and any(p in AGENT_HOMES for p in parts[:i]):
            return True
    return False


def _cluster_value(token: str, with_value: set[str]) -> tuple[str | None, bool]:
    """For a short-option cluster such as -rt or -tDIR: (value-taking flag, value is the
    next argument). The first value-taking letter ends the cluster; the rest of the token,
    if any, is its value."""
    letters = token[1:]
    for k, ch in enumerate(letters):
        if "-" + ch in with_value:
            return "-" + ch, k == len(letters) - 1
    return None, False


def positionals(args: list[str], with_value: set[str]) -> list[str]:
    out, i = [], 0
    while i < len(args):
        a = args[i]
        if a == "--":
            out.extend(args[i + 1 :])
            break
        if a.startswith("--"):
            if a in with_value:  # `--flag value`; `--flag=value` carries its own value
                i += 1
        elif a.startswith("-") and a != "-":
            flag, takes_next = _cluster_value(a, with_value)
            if flag and takes_next:
                i += 1
        else:
            out.append(a)
        i += 1
    return out


def repo_basename(url: str) -> str:
    name = url.rstrip("/").split("/")[-1].split(":")[-1]
    return name.removesuffix(".git")


def opt_value(
    args: list[str], flags: tuple[str, ...], with_value: set[str] | None = None
) -> str | None:
    """Value of the first of `flags` present, in any of its forms: `--flag value`,
    `--flag=value`, `-f value`, `-fVALUE` and a short cluster such as `-rf value`.
    None when absent or dangling at the end."""
    with_value = set(with_value or ()) | set(flags)
    for i, a in enumerate(args):
        if a == "--":
            break
        nxt = args[i + 1] if i + 1 < len(args) else None
        if a in flags:
            return nxt
        if a.startswith("--"):
            for f in flags:
                if f.startswith("--") and a.startswith(f + "="):
                    return a[len(f) + 1 :]
        elif a.startswith("-") and len(a) > 2:
            flag, takes_next = _cluster_value(a, with_value)
            if flag in flags:
                return nxt if takes_next else a[a.index(flag[1]) + 1 :]
    return None


def mentions_skills(text: str) -> bool:
    return "skills" in text


def detect(command: str, cwd: Path) -> tuple[list[dict], str | None]:
    """Return (install targets, tamper-reason). A target: {kind, source, skill?}.

    Each sub-command is parsed on its own: one that cannot be parsed never hides the
    others, and if it mentions a skills directory it becomes an 'unparsed' target
    (asked about, not passed).
    """
    if not any(k in command for k in KEYWORDS):
        return [], None
    targets: list[dict] = []
    # True when anything in the chain names a skills dir or an agent home, so a
    # destination the shell will expand (glob, variable, substitution) may land there.
    near = mentions_skills(command) or any(h in command for h in AGENT_HOMES)
    others: list[str] = []
    for sub in split_chain(command):
        argv = strip_wrappers(words(sub))
        if not argv:
            continue
        before = len(targets)
        try:
            cwd, tamper = _detect_one(argv, cwd, targets, near)
        except Exception:  # noqa: BLE001 -- unparseable input fails closed below
            if mentions_skills(sub):
                targets.append({"kind": "unparsed", "source": sub.strip()})
            continue
        if tamper:
            return [], tamper
        if len(targets) == before and os.path.basename(argv[0]) not in BENIGN_IN_CHAIN:
            others.append(sub.strip())
    # The gate scans before the whole chain runs, so any other step can change a source,
    # a git config or a remote after the scan. Ask rather than pass on a stale verdict.
    if targets and others:
        targets.append(
            {
                "kind": "chained",
                "source": "; ".join(others)[:200],
            }
        )
    return targets, None


def _detect_one(
    argv: list[str], cwd: Path, targets: list[dict], near: bool = False
) -> tuple[Path, str | None]:
    """Parse one sub-command; append any install targets. Returns (cwd, tamper)."""
    cmd, args = os.path.basename(argv[0]), argv[1:]
    joined = " ".join(argv)
    # Substring, not an argv match: a pty wrapper (`script -qc "... approve ..."`)
    # carries the whole call in one argument and also supplies the tty approve wants.
    if "skillspector-gate" in joined and re.search(r"\bapprove\b", joined):
        return cwd, "approving a SkillSpector gate verdict is reserved for the human"
    # Reading a protected file is fine; a redirect makes any command a writer.
    reads = (
        cmd in ("cat", "less", "jq") or (cmd == "rtk" and args[:1] == ["read"])
    ) and (not any(">" in a for a in args))
    # Command substitution is split across tokens by shlex, so no single token shows it;
    # in an install command near a skills dir, the shell decides the path, not us.
    if near and cmd in INSTALL_CMDS and re.search(r"\$\(|`", joined):
        targets.append({"kind": "unparsed", "source": joined})
        return cwd, None
    for name in PROTECTED_NAMES:
        if name in joined and not reads:
            reason = (
                f"{name} is maintained by the SkillSpector gate itself; only the gate "
                "and `skillspector-gate approve` may write it"
            )
            return cwd, reason
    if cmd == "cd":
        return (expand(args[0], cwd) if args else HOME), None
    if cmd == "git":
        # `git -C dir` changes only this git process's directory; the shell's cwd, which
        # later commands in the chain use, stays as it was.
        rest, gcwd = args, cwd
        while rest and rest[0] in ("-C", "-c") and len(rest) > 1:
            if rest[0] == "-C":
                gcwd = expand(rest[1], gcwd)
            rest = rest[2:]
        if not rest or rest[0] != "clone":
            return cwd, None
        pos = positionals(rest[1:], GIT_OPTS_WITH_VALUE)
        if not pos:
            return cwd, None
        url = pos[0]
        dest = expand(pos[1], gcwd) if len(pos) > 1 else gcwd / repo_basename(url)
        if near and len(pos) > 1 and opaque(pos[1], dest):
            targets.append({"kind": "unparsed", "source": joined})
            return cwd, None
        if in_skills_dir(dest):
            ref = opt_value(rest[1:], ("-b", "--branch"), GIT_OPTS_WITH_VALUE)
            targets.append(
                {"kind": "git", "source": url, "ref": ref, "dest": str(dest)}
            )
    elif cmd in ("cp", "mv", "rsync", "ln", "install"):
        if cmd == "rsync":
            pos, tdir = positionals(args, RSYNC_OPTS_WITH_VALUE), None
        else:
            pos = positionals(args, COPY_OPTS_WITH_VALUE)
            tdir = opt_value(args, ("-t", "--target-directory"), COPY_OPTS_WITH_VALUE)
        if tdir:
            raw_dest, srcs = tdir, pos
        elif len(pos) >= 2:
            raw_dest, srcs = pos[-1], pos[:-1]
        else:
            return cwd, None
        dest = expand(raw_dest, cwd)
        if near and (
            opaque(raw_dest, dest)
            or (in_skills_dir(dest) and any(opaque(s, expand(s, cwd)) for s in srcs))
        ):
            targets.append({"kind": "unparsed", "source": joined})
            return cwd, None
        if in_skills_dir(dest):
            for s in srcs:
                sp = expand(s.rstrip("/") if s != "/" else s, cwd)
                # Sources already inside a skills dir are scanned too: Write/Edit can change
                # an installed skill after it passed, so its location proves nothing about
                # its current content. The content-keyed cache keeps unchanged skills free.
                # A link keeps following its source, so whatever is scanned now can be
                # edited after it passes; no verdict can bind to what will run.
                kind = "link" if cmd == "ln" else "path"
                targets.append({"kind": kind, "source": str(sp)})
    elif cmd == "unzip":
        pos = positionals(args, {"-d", "-x", "-P"})
        d = opt_value(args, ("-d",), {"-d", "-x", "-P"})
        dest = expand(d, cwd) if d else cwd
        if near and d and opaque(d, dest):
            targets.append({"kind": "unparsed", "source": joined})
            return cwd, None
        if pos and in_skills_dir(dest):
            targets.append({"kind": "path", "source": str(expand(pos[0], cwd))})
    elif cmd in ("tar", "bsdtar"):
        flags = "".join(a for a in args if a.startswith("-")) + (
            args[0] if args and not args[0].startswith("-") else ""
        )
        if "x" not in flags and "--extract" not in args:
            return cwd, None
        d = opt_value(
            args, ("-C", "--directory"), {"-C", "--directory", "-f", "--file"}
        )
        dest = expand(d, cwd) if d else cwd
        if near and d and opaque(d, dest):
            targets.append({"kind": "unparsed", "source": joined})
            return cwd, None
        archive = None
        for i, a in enumerate(args):
            if a.startswith("--file="):
                archive = a[len("--file=") :]
            elif a in ("-f", "--file") or (
                a.startswith("-") and not a.startswith("--") and a.endswith("f")
            ):
                if i + 1 < len(args):
                    archive = args[i + 1]
            elif not a.startswith("-") and i == 0 and "f" in a and len(args) > 1:
                archive = args[1]
        if archive and in_skills_dir(dest):
            targets.append({"kind": "path", "source": str(expand(archive, cwd))})
    elif cmd in ("npx", "bunx", "pnpx", "pnpm", "npm", "yarn", "bun"):
        rest = args
        if (
            (cmd in ("pnpm", "yarn") and rest[:1] == ["dlx"])
            or (cmd == "npm" and rest[:1] in (["exec"], ["x"]))
            or (cmd == "bun" and rest[:1] == ["x"])
        ):
            rest = rest[1:]
        elif cmd in ("pnpm", "npm", "yarn", "bun"):
            return cwd, None
        pos = positionals(rest, {"--skill", "-s", "-a", "--agent", "-p", "--package"})
        if (
            len(pos) >= 3
            and re.sub(r"@[^/]*$", "", pos[0]) in ("skills", "add-skill")
            and pos[1] in ("add", "install", "i")
        ):
            skill = opt_value(
                rest,
                ("--skill", "-s"),
                {"--skill", "-s", "-a", "--agent", "-p", "--package"},
            )
            targets.append(
                {"kind": "spec", "source": local_spec(pos[2], cwd), "skill": skill}
            )
        elif len(pos) >= 2 and re.sub(r"@[^/]*$", "", pos[0]) == "add-skill":
            targets.append(
                {"kind": "spec", "source": local_spec(pos[1], cwd), "skill": None}
            )
    return cwd, None


# --- materialising and hashing targets ---------------------------------------------------


def local_spec(spec: str, cwd: Path) -> str:
    """A local skill spec (./x, ../x, /x, ~/x, or an existing relative path) as an absolute
    path against the command's tracked cwd. materialise() runs in the hook's own cwd, so a
    relative spec left as-is could scan a different directory than the one installed."""
    if spec.startswith((".", "/", "~")) or expand(spec, cwd).exists():
        return str(expand(spec, cwd))
    return spec


def github_url(spec: str) -> tuple[str, str | None, str | None]:
    """Map owner/repo, github tree URLs and plain git URLs to (clone-url, ref, subpath)."""
    m = re.match(
        r"^https://github\.com/([^/]+)/([^/]+?)(?:\.git)?/tree/([^/]+)/?(.*)$", spec
    )
    if m:
        return f"https://github.com/{m[1]}/{m[2]}.git", m[3], m[4] or None
    if re.match(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", spec):
        return f"https://github.com/{spec}.git", None, None
    return spec, None, None


def clone(url: str, ref: str | None, into: Path) -> Path:
    cmd = [
        "git",
        "-c",
        "core.hooksPath=/dev/null",
        "-c",
        "protocol.file.allow=never",
        "clone",
        "--depth",
        "1",
        "--no-recurse-submodules",
        "--quiet",
    ]
    if ref:
        cmd += ["--branch", ref]
    cmd += ["--", url, str(into / "repo")]
    env = {**os.environ, "GIT_TERMINAL_PROMPT": "0", "GIT_LFS_SKIP_SMUDGE": "1"}
    r = subprocess.run(
        cmd, capture_output=True, text=True, timeout=180, env=env, check=False
    )
    if r.returncode != 0:
        raise GateError(f"could not clone {url}: {r.stderr.strip()[:300]}")
    return into / "repo"


def check_archive_size(archive: Path, members: int, expanded: int) -> None:
    if members > MAX_ARCHIVE_MEMBERS:
        raise GateError(
            f"archive has {members} members (limit {MAX_ARCHIVE_MEMBERS}): {archive}"
        )
    if expanded > MAX_ARCHIVE_BYTES:
        raise GateError(
            f"archive expands to {expanded // 2**20} MB (limit "
            f"{MAX_ARCHIVE_BYTES // 2**20} MB): {archive}"
        )


def extract(archive: Path, into: Path) -> Path:
    out = into / "extracted"
    out.mkdir()
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as z:
            infos = z.infolist()
            check_archive_size(archive, len(infos), sum(i.file_size for i in infos))
            for info in infos:
                target = (out / info.filename).resolve()
                if not str(target).startswith(str(out.resolve())):
                    raise GateError(
                        f"archive member escapes extraction dir: {info.filename}"
                    )
            z.extractall(out)
    elif tarfile.is_tarfile(archive):
        with tarfile.open(archive) as t:
            members = t.getmembers()  # reads headers only; no file data is written
            check_archive_size(
                archive, len(members), sum(m.size for m in members if m.isfile())
            )
            t.extractall(out, members=members, filter="data")
    else:
        raise GateError(f"not a zip or tar archive: {archive}")
    return out


def materialise(target: dict, scratch: Path) -> Path:
    src, kind = target["source"], target["kind"]
    if kind == "git":
        return clone(src, target.get("ref"), scratch)
    if kind == "spec":
        local = Path(os.path.expanduser(src))
        if src.startswith((".", "/", "~")) or local.exists():
            return materialise({"kind": "path", "source": str(local)}, scratch)
        url, ref, sub = github_url(src)
        repo = clone(url, ref, scratch)
        return repo / sub if sub else repo
    path = Path(src)
    if not path.exists():
        raise GateError(f"install source does not exist: {path}")
    if path.is_file() and path.suffix.lower() in (
        ".zip",
        ".tar",
        ".gz",
        ".tgz",
        ".xz",
        ".bz2",
    ):
        return extract(path, scratch)
    return path


def find_skills(root: Path, only: str | None) -> list[Path]:
    if root.is_file():
        return [root] if root.name.lower().endswith(".md") else []
    if (root / "SKILL.md").is_file():
        found = [root]
    else:
        found = []
        for p in sorted(root.rglob("SKILL.md")):
            rel = p.relative_to(root).parts
            if len(rel) <= 5 and not any(x in (".git", "node_modules") for x in rel):
                found.append(p.parent)
    if only:
        found = [d for d in found if d.name == only or skill_name(d) == only]
    return found


def skill_name(d: Path) -> str | None:
    try:
        head = (d / "SKILL.md").read_text(encoding="utf-8", errors="replace")[:2000]
    except OSError:
        return None
    m = re.search(r"^name:\s*['\"]?([^'\"\n]+)", head, re.MULTILINE)
    return m[1].strip() if m else None


def tree_hash(path: Path) -> str:
    h, total = hashlib.sha256(), 0
    files = (
        [path]
        if path.is_file()
        else sorted(
            p
            for p in path.rglob("*")
            if p.is_file() and ".git" not in p.relative_to(path).parts
        )
    )
    for f in files:
        total += f.stat().st_size
        if total > MAX_TREE_BYTES:
            raise GateError(
                f"skill is larger than {MAX_TREE_BYTES // 2**20} MB: {path}"
            )
        rel = f.name if path.is_file() else f.relative_to(path).as_posix()
        h.update(rel.encode() + b"\0" + f.read_bytes() + b"\0")
    return h.hexdigest()


# --- verdicts ------------------------------------------------------------------------------


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def save_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=1, sort_keys=True), encoding="utf-8")
    tmp.replace(path)


def config_key() -> str:
    env = {
        k: os.environ.get(k, v)
        for k, v in SCAN_ENV_DEFAULTS.items()
        if k != "SKILLSPECTOR_MODEL_REGISTRY"
    }
    return json.dumps(env, sort_keys=True)


SCAN_SNIPPET = (
    "import asyncio, json, sys\n"
    "from skillspector.mcp_server import run_scan\n"
    "r = asyncio.run(run_scan(sys.argv[1], use_llm=True, output_format='json'))\n"
    "r.pop('report', None)\n"
    "print('\\n@@VERDICT@@' + json.dumps(r))\n"
)


def run_scanner(skill: Path, timeout: float) -> dict:
    override = os.environ.get("SKILLSPECTOR_GATE_SCANNER")  # tests: a stub executable
    argv = (
        [override, str(skill)]
        if override
        else [SKILLSPECTOR_PY, "-I", "-c", SCAN_SNIPPET, str(skill)]
    )
    env = {**SCAN_ENV_DEFAULTS, **os.environ}
    try:
        r = subprocess.run(
            argv,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
            cwd=tempfile.gettempdir(),
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise GateError(
            f"SkillSpector timed out after {int(timeout)} s on {skill.name}"
        ) from exc
    except OSError as exc:
        raise GateError(f"could not run SkillSpector: {exc}") from exc
    marker = r.stdout.rfind("@@VERDICT@@")
    if marker < 0:
        raise GateError(
            f"SkillSpector failed on {skill.name}: {(r.stderr or r.stdout).strip()[-400:]}"
        )
    return json.loads(r.stdout[marker + len("@@VERDICT@@") :])


def summarise(name: str, v: dict) -> str:
    head = (
        f"{name}: {v.get('recommendation')} (risk {v.get('risk_score')}/100, "
        f"{v.get('severity')}, scan {v.get('scan_mode')})"
    )
    lines = [head]
    for f in sorted(
        v.get("findings", []), key=lambda f: -SEV.get(str(f.get("severity")).upper(), 0)
    )[:4]:
        where = f.get("location") or {}
        loc = where.get("file") or f.get("file_path") or f.get("file") or ""
        if loc and where.get("start_line"):
            loc = f"{loc}:{where['start_line']}"
        title = (
            f.get("finding")
            or f.get("title")
            or f.get("category")
            or f.get("id")
            or "finding"
        )
        lines.append(f"  - [{f.get('severity')}] {str(title)[:110]} {loc}".rstrip())
    return "\n".join(lines)


SEV = {"CRITICAL": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1}


def is_remote(t: dict) -> bool:
    """True for sources the agent's command fetches again after the scan (git clone, a
    `skills add` spec that is not a local path)."""
    if t["kind"] == "git":
        return True
    return t["kind"] == "spec" and not Path(t["source"]).is_absolute()


def evaluate(
    targets: list[dict], deadline: float, bindings: list[dict] | None = None
) -> tuple[str, str]:
    """Return (decision, reason). decision in pass|ask|deny. When `bindings` is a list,
    every scanned skill of a remote source is appended to it for post-install checks."""
    approvals = load_json(STATE_DIR / APPROVALS_NAME)
    cache = load_json(CACHE_FILE)
    worst, notes = "pass", []
    with tempfile.TemporaryDirectory(prefix="skillspector-gate-") as tmp:
        for n, t in enumerate(targets):
            if t["kind"] == "unparsed":
                worst = max_dec(worst, "ask")
                notes.append(
                    f"'{t['source']}' touches a skills directory but could not be parsed, "
                    "so the gate cannot tell what it installs"
                )
                continue
            if t["kind"] == "chained":
                worst = max_dec(worst, "ask")
                notes.append(
                    f"the install is chained with other steps ({t['source']}), which run "
                    "after the scan and could change what is installed; run the install "
                    "on its own"
                )
                continue
            if t["kind"] == "link":
                worst = max_dec(worst, "ask")
                notes.append(
                    f"{t['source']}: a linked skill keeps following its source, so a scan "
                    "cannot cover what will actually run; copy it (cp -r) instead"
                )
                continue
            scratch = Path(tmp) / str(n)
            scratch.mkdir()
            try:
                root = materialise(t, scratch)
                skills = find_skills(root, t.get("skill"))
            except (GateError, OSError) as exc:
                # One unreadable target must not discard what the others found: note it,
                # ask, and keep scanning so a later DO_NOT_INSTALL still denies.
                worst = max_dec(worst, "ask")
                notes.append(f"{t['source']}: could not be scanned: {exc}")
                continue
            if not skills:
                worst = max_dec(worst, "ask")
                notes.append(
                    f"{t['source']}: no SKILL.md found, so SkillSpector cannot scan it"
                )
                continue
            if len(skills) > MAX_SKILLS:
                worst = max_dec(worst, "ask")
                notes.append(
                    f"{t['source']}: {len(skills)} skills exceeds the gate's limit of "
                    f"{MAX_SKILLS}; install them one at a time with --skill"
                )
                continue
            for d in skills:
                digest = tree_hash(d)
                label = f"{t['source']}{'' if d == root else ' :: ' + d.name}"
                if bindings is not None and is_remote(t):
                    bindings.append(
                        {
                            "kind": t["kind"],
                            "source": t["source"],
                            "dest": t.get("dest"),
                            "rel": "" if d == root else d.relative_to(root).as_posix(),
                            "name": skill_name(d) or d.name,
                            "digest": digest,
                        }
                    )
                if digest in approvals:
                    notes.append(
                        f"{label}: approved by the user on {approvals[digest].get('date')}"
                    )
                    continue
                key = digest + "|" + config_key()
                hit = cache.get(key)
                if hit and time.time() - hit.get("at", 0) < CACHE_TTL:
                    v = hit["verdict"]
                else:
                    remaining = deadline - time.time()
                    if remaining < 60:
                        raise GateError("ran out of time before scanning every skill")
                    v = run_scanner(d, min(PER_SCAN_TIMEOUT, remaining))
                    cache[key] = {"at": time.time(), "verdict": v}
                    save_json(CACHE_FILE, cache)
                if v.get("safe_to_install"):
                    notes.append(f"{label}: SAFE (risk {v.get('risk_score')}/100)")
                    continue
                dec = "deny" if v.get("recommendation") == "DO_NOT_INSTALL" else "ask"
                worst = max_dec(worst, dec)
                notes.append(summarise(label, v))
                if worst == "deny":
                    # Final: nothing scanned later can lift a deny, and a later error or
                    # timeout must not replace it with an ask.
                    return worst, "\n".join(notes)
    return worst, "\n".join(notes)


def max_dec(a: str, b: str) -> str:
    order = {"pass": 0, "ask": 1, "deny": 2}
    return a if order[a] >= order[b] else b


# --- agent protocols -------------------------------------------------------------------


def read_payload(agent: str) -> tuple[str, Path, str | None]:
    """Return (command, cwd, permission_mode). permission_mode is None when the agent
    does not report one."""
    data = json.loads(sys.stdin.read() or "{}")
    if agent == "agy":
        call = data.get("toolCall") or {}
        if call.get("name") != "run_command":
            return "", HOME, None
        args = call.get("args") or {}
        ws = (data.get("workspacePaths") or [str(HOME)])[0]
        return str(args.get("CommandLine") or ""), Path(args.get("Cwd") or ws), None
    ti = data.get("tool_input") or {}
    cmd = ti.get("command") or ""
    if isinstance(cmd, list):
        cmd = shlex.join(cmd)
    mode = data.get("permission_mode")
    return (
        str(cmd),
        Path(ti.get("workdir") or data.get("cwd") or HOME),
        (str(mode) if mode else None),
    )


# Claude Code permission modes in which an "ask" actually reaches a person. In any other
# reported mode (auto, bypassPermissions, dontAsk, ...) an "ask" is settled without the
# user -- verified 2026-11-07: under auto mode a CAUTION install was approved by the auto
# classifier with no prompt -- so the gate escalates it to "deny" and points at
# `skillspector-gate approve`, which only a person at a terminal can run.
PROMPTING_MODES = {"default", "acceptEdits", "plan"}
AUDIT_LOG = CACHE_FILE.parent / "decisions.log"


def audit(agent: str, mode: str | None, decision: str, sources: list[str]) -> None:
    """Append one line per recognised install. Paths and verdicts only; never tokens."""
    try:
        AUDIT_LOG.parent.mkdir(parents=True, exist_ok=True)
        with AUDIT_LOG.open("a", encoding="utf-8") as fh:
            fh.write(
                json.dumps(
                    {
                        "at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
                        "agent": agent,
                        "permission_mode": mode,
                        "decision": decision,
                        "sources": sources,
                    }
                )
                + "\n"
            )
    except OSError:
        pass  # auditing must never change the decision


def emit(agent: str, decision: str, reason: str) -> None:
    if decision == "pass":
        if agent == "agy":
            print(json.dumps({"decision": "allow"}))
        return
    if agent == "codex" and decision == "ask":
        decision = "deny"  # Codex rejects permissionDecision "ask"
    if agent == "agy":
        print(
            json.dumps(
                {
                    "decision": "force_ask" if decision == "ask" else "deny",
                    "reason": reason,
                }
            )
        )
        return
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": decision,
                    "permissionDecisionReason": reason,
                }
            }
        )
    )


APPROVE_HINT = (
    "If the user has read the findings and still wants it, they can accept this "
    "exact content from their own terminal (not through an agent): "
    "skillspector-gate approve {src}"
)


def escalate(agent: str, mode: str | None, decision: str) -> tuple[str, str]:
    """Turn an 'ask' that nobody would see into a 'deny'. Returns (decision, note)."""
    if (
        decision == "ask"
        and agent == "claude"
        and mode is not None
        and mode not in PROMPTING_MODES
    ):
        return "deny", (
            f"Claude Code is in '{mode}' permission mode, where a confirmation is settled "
            f"without the user, so the gate blocks instead of asking.\n"
        )
    return decision, ""


def command_key(command: str) -> str:
    return hashlib.sha256(command.strip().encode()).hexdigest()


def record_pending(command: str, cwd: Path, bindings: list[dict]) -> None:
    """Remember what was scanned for this exact command, for the post-install check."""
    if not bindings:
        return
    pending = load_json(PENDING_FILE)
    now = time.time()
    pending = {k: v for k, v in pending.items() if now - v.get("at", 0) < PENDING_TTL}
    pending[command_key(command)] = {"at": now, "cwd": str(cwd), "items": bindings}
    save_json(PENDING_FILE, pending)


def skills_dirs(cwd: Path) -> list[Path]:
    out = []
    for base in (HOME, cwd):
        for home in sorted(AGENT_HOMES):
            d = base / home / "skills"
            if d.is_dir() and d not in out:
                out.append(d)
    return out


def locate(item: dict, cwd: Path, since: float) -> tuple[Path | None, Path | None]:
    """(installed skill dir, install root to quarantine) for one scanned skill."""
    if item["kind"] == "git" and item.get("dest"):
        root = Path(item["dest"])
        skill = root / item["rel"] if item["rel"] else root
        return (skill, root) if skill.exists() else (None, None)
    # `skills add` picks its own destination: find the skill by name, newest first,
    # installed no earlier than the scan.
    name, found = item["name"], []
    for sd in skills_dirs(cwd):
        for d in sd.iterdir():
            if not d.is_dir():
                continue
            if d.name == name or skill_name(d) == name:
                mt = d.stat().st_mtime
                if mt >= since - 5:
                    found.append((mt, d))
    if not found:
        return None, None
    d = max(found)[1]
    return d, d


def quarantine(path: Path) -> Path:
    QUARANTINE_DIR.mkdir(parents=True, exist_ok=True)
    dest = QUARANTINE_DIR / f"{time.strftime('%Y%m%d-%H%M%S')}-{path.name}"
    n = 1
    while dest.exists():
        n += 1
        dest = dest.with_name(f"{dest.name}-{n}")
    shutil.move(str(path), str(dest))
    return dest


def post(agent: str) -> int:
    """PostToolUse: check that what a remote install wrote is what the gate scanned."""
    try:
        command, cwd, mode = read_payload(agent)
    except Exception:  # noqa: BLE001 -- nothing to verify without a command
        return 0
    if not command:
        return 0
    pending = load_json(PENDING_FILE)
    entry = pending.pop(command_key(command), None)
    if entry is None:
        return 0
    save_json(PENDING_FILE, pending)
    since = entry.get("at", 0)
    bad, unverified, sources = [], [], []
    for item in entry.get("items", []):
        label = item["source"] + (f" :: {item['name']}" if item.get("rel") else "")
        sources.append(label)
        try:
            installed, root = locate(item, Path(entry.get("cwd") or cwd), since)
        except OSError:
            installed, root = None, None
        if installed is None or root is None:
            unverified.append(label)
            continue
        try:
            got = tree_hash(installed)
        except (GateError, OSError):
            got = None
        if got == item["digest"]:
            continue
        try:
            moved = quarantine(root)
            bad.append(
                f"{label}: installed content differs from what was scanned; moved to {moved}"
            )
        except OSError as exc:
            bad.append(
                f"{label}: installed content differs from what was scanned and could not be quarantined ({exc}); remove {root} by hand"
            )
    if bad:
        audit(agent, mode, "quarantined", sources)
        reason = (
            "SkillSpector gate: the installed skill does not match the content that was "
            "scanned before the install (the source changed, or served different bytes "
            "to the second fetch). It was NOT left in place:\n"
            + "\n".join(bad)
            + "\nRe-run the install so the gate scans what will really be installed."
        )
        if agent == "agy":
            print(reason, file=sys.stderr)
        else:
            print(
                json.dumps(
                    {
                        "decision": "block",
                        "reason": reason,
                        "hookSpecificOutput": {
                            "hookEventName": "PostToolUse",
                            "additionalContext": reason,
                        },
                    }
                )
            )
        return 0
    if unverified:
        audit(agent, mode, "unverified", unverified)
        print(
            "SkillSpector gate: could not locate the installed skill to verify it against the "
            "scan: " + ", ".join(unverified),
            file=sys.stderr,
        )
        return 0
    audit(agent, mode, "verified", sources)
    return 0


def hook(agent: str) -> int:
    try:
        command, cwd, mode = read_payload(agent)
    except Exception:  # noqa: BLE001 -- an unreadable payload has no command to judge
        emit(agent, "pass", "")
        return 0
    try:
        targets, tamper = detect(command, cwd)
    except Exception:  # noqa: BLE001 -- fail closed only where a skills dir is involved
        if not mentions_skills(command):
            emit(agent, "pass", "")
            return 0
        targets, tamper = [{"kind": "unparsed", "source": command.strip()}], None
    if tamper:
        audit(agent, mode, "deny", ["tamper: " + tamper])
        emit(agent, "deny", f"SkillSpector gate: {tamper}.")
        return 0
    if not targets:
        emit(agent, "pass", "")
        return 0
    sources = [t["source"] for t in targets]
    srcs = " ".join(shlex.quote(s) for s in sources)
    bindings: list[dict] = []
    try:
        decision, notes = evaluate(targets, time.time() + TOTAL_BUDGET, bindings)
    except Exception as exc:  # noqa: BLE001 -- fail closed once an install is recognised
        decision, note = escalate(agent, mode, "ask")
        audit(agent, mode, decision, sources)
        emit(
            agent,
            decision,
            f"SkillSpector gate could not finish the pre-install scan: {exc}\n"
            + note
            + APPROVE_HINT.format(src=srcs),
        )
        return 0
    decision, note = escalate(agent, mode, decision)
    audit(agent, mode, decision, sources)
    if decision != "deny":
        # pass, or an ask the user may accept: the command can still run, so remember
        # what was scanned for the post-install check. A write failure only means the
        # post check finds nothing to verify; the scan's verdict still stands.
        with contextlib.suppress(OSError):
            record_pending(command, cwd, bindings)
    if decision == "pass":
        if notes:
            print(f"SkillSpector gate: {notes}", file=sys.stderr)
        emit(agent, "pass", "")
        return 0
    verb = "blocked" if decision == "deny" else "needs confirmation"
    emit(
        agent,
        decision,
        f"SkillSpector gate: skill install {verb}.\n{notes}\n"
        + note
        + APPROVE_HINT.format(src=srcs),
    )
    return 0


def resolve_cli_targets(target: str, skill: str | None) -> list[dict]:
    p = Path(os.path.expanduser(target))
    if p.exists():
        return [{"kind": "path", "source": str(p.resolve()), "skill": skill}]
    return [{"kind": "spec", "source": target, "skill": skill}]


def approve(target: str, skill: str | None) -> int:
    if not sys.stdin.isatty():
        print(
            "approve must be run by a person in an interactive terminal.",
            file=sys.stderr,
        )
        return 2
    approvals = load_json(STATE_DIR / APPROVALS_NAME)
    with tempfile.TemporaryDirectory(prefix="skillspector-gate-") as tmp:
        t = resolve_cli_targets(target, skill)[0]
        root = materialise(t, Path(tmp))
        skills = find_skills(root, skill)
        if not skills:
            print(f"no SKILL.md found under {target}", file=sys.stderr)
            return 1
        for d in skills:
            digest = tree_hash(d)
            approvals[digest] = {
                "source": target,
                "skill": d.name,
                "date": time.strftime("%Y-%m-%d %H:%M"),
            }
            print(f"approved {d.name}  sha256:{digest[:16]}...")
    save_json(STATE_DIR / APPROVALS_NAME, approvals)
    print(
        "Approval covers this exact content only; any change to the skill is scanned again."
    )
    return 0


def check(target: str, skill: str | None) -> int:
    decision, notes = evaluate(
        resolve_cli_targets(target, skill), time.time() + TOTAL_BUDGET
    )
    print(notes)
    print(f"gate decision: {decision}")
    return 0 if decision == "pass" else 1


def main() -> int:
    ap = argparse.ArgumentParser(
        prog="skillspector-gate", description=(__doc__ or "").split("\n\n")[0]
    )
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("hook", "post"):
        h = sub.add_parser(name)
        h.add_argument("--agent", choices=("claude", "codex", "agy"), required=True)
    for name in ("approve", "check"):
        p = sub.add_parser(name)
        p.add_argument("target")
        p.add_argument("--skill")
    a = ap.parse_args()
    if a.cmd == "hook":
        return hook(a.agent)
    if a.cmd == "post":
        return post(a.agent)
    if a.cmd == "approve":
        return approve(a.target, a.skill)
    return check(a.target, a.skill)


if __name__ == "__main__":
    sys.exit(main())
