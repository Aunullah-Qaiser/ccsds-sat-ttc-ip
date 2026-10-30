#!/usr/bin/env python3
"""
===============================================================================
File Name   : sync_from_gdrive.py
Project     : CCSDS-SAT-TTC-IP (Spacecraft Flight TT&C & Hardware EGSE IP)
Description : Permanent Local Sync Script for Google Drive for Desktop.
              Finds the `CCSDS_SAT_TTC_IP_Sync` folder mounted by Google Drive
              for Desktop on Windows (e.g., `G:\\My Drive\\CCSDS_SAT_TTC_IP_Sync`),
              reads the newest `ccsds_latest_sync*.json` bundle, updates
              changed files in the local repository, and removes any deprecated
              or temporary files listed in `delete_files` / `delete_globs`.

Usage (PowerShell / CMD from your local repo root):
    python scripts/sync_from_gdrive.py
    .\\scripts\\sync_from_gdrive.bat
===============================================================================
"""

from __future__ import annotations
import argparse
import base64
import hashlib
import json
import os
import zlib
from pathlib import Path
from typing import Optional, List


FOLDER_NAME = "CCSDS_SAT_TTC_IP_Sync"


def find_gdrive_sync_dir(script_path: Path, explicit_dir: Optional[str] = None) -> Path:
    candidates: List[Path] = []
    if explicit_dir:
        candidates.append(Path(explicit_dir))
    if os.environ.get("CCSDS_GDRIVE_SYNC_DIR"):
        candidates.append(Path(os.environ["CCSDS_GDRIVE_SYNC_DIR"]))

    # If this script itself is being executed directly from CCSDS_SAT_TTC_IP_Sync
    if script_path.parent.name == FOLDER_NAME or list(script_path.parent.glob("ccsds_latest_sync*.json")):
        candidates.append(script_path.parent)

    # Scan Windows drive letters (G:\My Drive\..., etc.)
    for letter in "GHIJKLMNOPQRSTUVWXYZCDEF":
        drive_root = Path(f"{letter}:\\")
        try:
            if drive_root.exists():
                candidates.append(drive_root / "My Drive" / FOLDER_NAME)
                candidates.append(drive_root / FOLDER_NAME)
        except OSError:
            continue

    home = Path.home()
    candidates.extend([
        home / "Google Drive" / "My Drive" / FOLDER_NAME,
        home / "Google Drive" / FOLDER_NAME,
        home / "My Drive" / FOLDER_NAME,
    ])

    for cand in candidates:
        try:
            if cand.exists() and cand.is_dir():
                return cand
        except OSError:
            continue

    raise FileNotFoundError(
        f"Could not auto-detect '{FOLDER_NAME}' in Google Drive for Desktop.\n"
        f"Please pass --sync-dir \"<path-to-{FOLDER_NAME}>\" or set CCSDS_GDRIVE_SYNC_DIR."
    )


def resolve_repo_root(script_path: Path, explicit_repo: Optional[str] = None) -> Path:
    if explicit_repo:
        return Path(explicit_repo).resolve()
    # If located in <repo>/scripts/sync_from_gdrive.py
    if script_path.parent.name == "scripts" and (script_path.parent.parent / "rtl").exists():
        return script_path.parent.parent
    # Otherwise use current working directory (e.g. when invoked from repo root)
    return Path.cwd().resolve()


def select_newest_bundle(sync_dir: Path) -> Path:
    bundles = list(sync_dir.glob("ccsds_latest_sync*.json"))
    if not bundles:
        raise FileNotFoundError(f"No 'ccsds_latest_sync*.json' found in {sync_dir}")

    def bundle_sort_key(p: Path):
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
            seq = int(data.get("sync_seq", 0))
            ts = str(data.get("timestamp_utc", ""))
            return (seq, ts, p.stat().st_mtime)
        except Exception:
            return (0, "", p.stat().st_mtime)

    bundles.sort(key=bundle_sort_key, reverse=True)
    return bundles[0]


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync CCSDS-SAT-TTC-IP from Google Drive for Desktop")
    parser.add_argument("--sync-dir", type=str, default=None, help="Path to CCSDS_SAT_TTC_IP_Sync folder")
    parser.add_argument("--repo-dir", type=str, default=None, help="Path to local ccsds_sat_ttc_ip repo")
    parser.add_argument("--force", action="store_true", help="Overwrite all files even if SHA-256 matches")
    args = parser.parse_args()

    script_path = Path(__file__).resolve()
    repo_root = resolve_repo_root(script_path, args.repo_dir)
    sync_dir = find_gdrive_sync_dir(script_path, args.sync_dir)
    bundle_path = select_newest_bundle(sync_dir)

    payload = json.loads(bundle_path.read_text(encoding="utf-8"))
    version = payload.get("version", "unknown")
    sync_seq = payload.get("sync_seq", 0)
    ts_utc = payload.get("timestamp_utc", "")
    desc = payload.get("description", "")
    files_map = payload.get("files_zlib_b64", {})
    plain_files_map = payload.get("files", {})
    if not files_map and not plain_files_map:
        raise RuntimeError(f"Bundle {bundle_path.name} contains no file entries!")
    delete_files = payload.get("delete_files", [])
    delete_globs = payload.get("delete_globs", [])

    print(f"[GDRIVE-SYNC] Source Folder : {sync_dir}")
    print(f"[GDRIVE-SYNC] Active Bundle : {bundle_path.name} (version={version}, seq={sync_seq}, ts={ts_utc})")
    print(f"[GDRIVE-SYNC] Target Repo   : {repo_root}")
    if desc:
        print(f"[GDRIVE-SYNC] Milestone Note: {desc}")

    updated_cnt = 0
    unchanged_cnt = 0
    deleted_cnt = 0

    all_items = [(k, v, True) for k, v in sorted(files_map.items())] + [
        (k, v, False) for k, v in sorted(plain_files_map.items()) if k not in files_map
    ]
    for rel_path, content_val, is_zb64 in all_items:
        if is_zb64:
            raw_bytes = zlib.decompress(base64.b64decode(content_val))
        elif isinstance(content_val, dict):
            enc = content_val.get("encoding", "utf-8")
            c_str = content_val.get("content", "")
            raw_bytes = base64.b64decode(c_str) if enc == "base64" else c_str.encode("utf-8")
        else:
            raw_bytes = content_val.encode("utf-8")
        target_path = repo_root / rel_path
        target_path.parent.mkdir(parents=True, exist_ok=True)

        if target_path.exists() and not args.force:
            cur_bytes = target_path.read_bytes()
            if hashlib.sha256(cur_bytes).digest() == hashlib.sha256(raw_bytes).digest():
                unchanged_cnt += 1
                continue

        target_path.write_bytes(raw_bytes)
        updated_cnt += 1
        print(f"  [SYNCED] {rel_path} ({len(raw_bytes)} bytes)")

    # Process explicit file deletions and glob pattern cleanups
    to_remove: set[Path] = set()
    for rel_del in delete_files:
        cand = repo_root / rel_del
        if cand.is_file():
            to_remove.add(cand)
    for pat in delete_globs:
        for cand in repo_root.glob(pat):
            if cand.is_file():
                to_remove.add(cand)

    for rem_path in sorted(to_remove):
        try:
            rel_str = str(rem_path.relative_to(repo_root))
        except ValueError:
            rel_str = str(rem_path)
        rem_path.unlink(missing_ok=True)
        deleted_cnt += 1
        print(f"  [CLEANED] Removed deprecated/stale file: {rel_str}")

    print(
        f"\n[GDRIVE-SYNC SUCCESS] {updated_cnt} file(s) updated, "
        f"{deleted_cnt} stale file(s) cleaned, "
        f"{unchanged_cnt} file(s) already up to date in {repo_root}"
    )
    next_cmds = payload.get("recommended_local_commands", [])
    if next_cmds:
        print("\nSuggested local commands:")
        for cmd in next_cmds:
            print(f"  {cmd}")


if __name__ == "__main__":
    main()
