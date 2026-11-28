#!/usr/bin/env python3
"""
Trixie ElevenLabs Audio Pipeline CLI (Plan Starter Safe).
Reads tools/audio_manifest.json, enforces credit estimation, sequential
rate-limiting (concurrency = 1), mp3_44100_128 download caching into
raw_assets/audio_api_raw/, and ffmpeg silence-trimmed WAV/OGG export into res://assets/audio/.

Zero external pip dependencies required (uses Python 3.10+ stdlib + local ffmpeg).
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import wave
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = PROJECT_ROOT / "tools" / "audio_manifest.json"
RAW_API_CACHE_DIR = PROJECT_ROOT / "raw_assets" / "audio_api_raw"
HISTORY_DIR = PROJECT_ROOT / "raw_assets" / "audio_history"
ENV_FILE = PROJECT_ROOT / ".env"

API_BASE = "https://api.elevenlabs.io"
STARTER_OUTPUT_FORMAT = "mp3_44100_128"


def load_api_key() -> str:
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if key:
        return key
    if ENV_FILE.exists():
        for raw_line in ENV_FILE.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            if k.strip() == "ELEVENLABS_API_KEY":
                return v.strip().strip('"').strip("'")
    return ""


def res_to_abs_path(res_path: str) -> Path:
    if res_path.startswith("res://"):
        rel = res_path[len("res://") :]
        return PROJECT_ROOT / rel
    return PROJECT_ROOT / res_path


def load_manifest(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def save_manifest(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


def api_get_json(endpoint: str, api_key: str) -> dict[str, Any] | list[Any]:
    req = urllib.request.Request(
        f"{API_BASE}{endpoint}",
        headers={"xi-api-key": api_key, "Accept": "application/json"},
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_subscription(api_key: str) -> dict[str, Any] | None:
    if not api_key:
        return None
    try:
        res = api_get_json("/v1/user/subscription", api_key)
        if isinstance(res, dict):
            return res
    except Exception:
        return None
    return None


def estimate_item_credits(item: dict[str, Any]) -> int:
    kind = item.get("type", "sfx")
    if kind == "tts":
        text = str(item.get("text", ""))
        return max(1, len(text))
    if kind == "sfx":
        dur = item.get("duration_seconds")
        if dur is None:
            return 200
        return max(1, int(math.ceil(float(dur) * 40.0)))
    if kind == "sts":
        est_dur = float(item.get("estimated_duration_sec", 2.5))
        return max(1, int(math.ceil((est_dur / 60.0) * 1000.0)))
    return 0


def api_post_json_binary(endpoint: str, payload: dict[str, Any], api_key: str) -> bytes:
    body = json.dumps(payload).encode("utf-8")
    delays = [2.0, 4.0, 8.0]
    attempt = 0
    while True:
        req = urllib.request.Request(
            f"{API_BASE}{endpoint}",
            data=body,
            headers={
                "xi-api-key": api_key,
                "Content-Type": "application/json",
                "Accept": "audio/mpeg",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=45) as resp:
                return resp.read()
        except urllib.error.HTTPError as err:
            err_body = err.read().decode("utf-8", "ignore")
            if err.code in (429, 500, 502, 503, 504) and attempt < len(delays):
                wait_s = delays[attempt]
                print(f"  [retry] HTTP {err.code}; waiting {wait_s:.1f}s...")
                time.sleep(wait_s)
                attempt += 1
                continue
            raise RuntimeError(f"ElevenLabs API HTTP {err.code} on {endpoint}: {err_body}") from err


def api_post_multipart_sts(
    voice_id: str,
    audio_file: Path,
    model_id: str,
    remove_bg_noise: bool,
    api_key: str,
) -> bytes:
    boundary = f"----TrixieAudioBoundary{uuid.uuid4().hex}"
    parts: list[bytes] = []

    def add_field(name: str, val: str) -> None:
        parts.append(f"--{boundary}\r\n".encode("utf-8"))
        parts.append(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode("utf-8"))
        parts.append(f"{val}\r\n".encode("utf-8"))

    add_field("model_id", model_id)
    add_field("remove_background_noise", "true" if remove_bg_noise else "false")

    parts.append(f"--{boundary}\r\n".encode("utf-8"))
    parts.append(
        f'Content-Disposition: form-data; name="audio"; filename="{audio_file.name}"\r\n'.encode("utf-8")
    )
    parts.append(b"Content-Type: audio/mpeg\r\n\r\n")
    parts.append(audio_file.read_bytes())
    parts.append(b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode("utf-8"))

    body = b"".join(parts)
    endpoint = f"/v1/speech-to-speech/{urllib.parse.quote(voice_id)}?output_format={STARTER_OUTPUT_FORMAT}"
    req = urllib.request.Request(
        f"{API_BASE}{endpoint}",
        data=body,
        headers={
            "xi-api-key": api_key,
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Accept": "audio/mpeg",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.read()
    except urllib.error.HTTPError as err:
        err_body = err.read().decode("utf-8", "ignore")
        raise RuntimeError(f"ElevenLabs STS HTTP {err.code}: {err_body}") from err


def ensure_sts_compatible_input(src_path: Path, item_id: str) -> Path:
    ext = src_path.suffix.lower()
    if ext in (".mp3", ".wav"):
        return src_path
    RAW_API_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    converted = RAW_API_CACHE_DIR / f"tmp_sts_in_{item_id}.mp3"
    cmd = [
        "ffmpeg",
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(src_path),
        "-ac",
        "1",
        "-ar",
        "44100",
        "-c:a",
        "libmp3lame",
        "-b:a",
        "192k",
        str(converted),
    ]
    subprocess.run(cmd, check=True)
    return converted


def get_wav_duration_sec(wav_path: Path) -> float:
    if not wav_path.exists() or wav_path.stat().st_size < 64:
        return 0.0
    with wave.open(str(wav_path), "rb") as wf:
        frames = wf.getnframes()
        rate = wf.getframerate()
        return float(frames) / float(rate) if rate > 0 else 0.0


def run_ffmpeg_post_process(raw_mp3: Path, out_path: Path, mode: str) -> float:
    out_path.parent.mkdir(parents=True, exist_ok=True)

    if mode == "ogg_loop_keep_edges":
        cmd = [
            "ffmpeg",
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(raw_mp3),
            "-ar",
            "44100",
            "-c:a",
            "libvorbis",
            "-q:a",
            "5",
            str(out_path),
        ]
        subprocess.run(cmd, check=True)
        return -1.0

    if mode == "wav_sfx_trim":
        af_primary = (
            "silenceremove=start_periods=1:start_duration=0.002:start_threshold=-50dB:start_silence=0.004,"
            "areverse,"
            "silenceremove=start_periods=1:start_duration=0.010:start_threshold=-52dB:start_silence=0.015,"
            "areverse"
        )
    else:
        # Default: wav_bark_trim (0ms crisp start + generous tail cushion so breathy laughs aren't clipped)
        af_primary = (
            "silenceremove=start_periods=1:start_duration=0.004:start_threshold=-50dB:start_silence=0.010,"
            "areverse,"
            "silenceremove=start_periods=1:start_duration=0.020:start_threshold=-58dB:start_silence=0.100,"
            "areverse"
        )

    def convert_wav(af_filter: str) -> None:
        cmd = [
            "ffmpeg",
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(raw_mp3),
            "-af",
            af_filter,
            "-ac",
            "1",
            "-ar",
            "44100",
            "-sample_fmt",
            "s16",
            str(out_path),
        ]
        subprocess.run(cmd, check=True)

    convert_wav(af_primary)
    dur = get_wav_duration_sec(out_path)
    if dur < 0.12:
        # Safety fallback at 0 API credit cost if a quiet sigh/cough was below -50dB
        af_gentle = (
            "silenceremove=start_periods=1:start_duration=0.002:start_threshold=-62dB:start_silence=0.012,"
            "areverse,"
            "silenceremove=start_periods=1:start_duration=0.015:start_threshold=-62dB:start_silence=0.120,"
            "areverse"
        )
        convert_wav(af_gentle)
        dur = get_wav_duration_sec(out_path)
    return dur


def select_items(
    manifest: dict[str, Any],
    ids: list[str] | None,
    character: str | None,
    item_type: str | None,
    force: bool,
) -> list[dict[str, Any]]:
    selected: list[dict[str, Any]] = []
    id_set = set(ids) if ids else None
    for item in manifest.get("items", []):
        iid = str(item.get("id", ""))
        status = str(item.get("status", "draft"))
        if id_set is not None and iid not in id_set:
            continue
        if character and str(item.get("character", "")) != character:
            continue
        if item_type and str(item.get("type", "")) != item_type:
            continue
        if not force and id_set is None and status not in ("pending", "regen_requested"):
            continue
        if not force and id_set is not None and status == "approved":
            print(f"  [skip] '{iid}' is locked as 'approved' (use --force to override).")
            continue
        selected.append(item)
    return selected


def _next_version_tag(item_id: str) -> str:
    item_hist_dir = HISTORY_DIR / item_id
    if not item_hist_dir.exists():
        return "v01"
    max_num = 0
    for meta_file in item_hist_dir.glob("v*.json"):
        m = re.fullmatch(r"v(\d+)", meta_file.stem)
        if m:
            max_num = max(max_num, int(m.group(1)))
    return f"v{max_num + 1:02d}"


def archive_item_files(
    item: dict[str, Any],
    raw_mp3: Path | None,
    out_path: Path,
    version_tag: str | None = None,
) -> str:
    iid = str(item["id"])
    ver = version_tag or _next_version_tag(iid)
    item_hist_dir = HISTORY_DIR / iid
    item_hist_dir.mkdir(parents=True, exist_ok=True)

    if raw_mp3 is not None and raw_mp3.exists():
        shutil.copy2(raw_mp3, item_hist_dir / f"{ver}.mp3")
    if out_path.exists():
        shutil.copy2(out_path, item_hist_dir / f"{ver}{out_path.suffix}")

    dur = item.get("duration_result_sec")
    if dur is None and out_path.suffix.lower() == ".wav" and out_path.exists():
        dur = round(get_wav_duration_sec(out_path), 3)

    meta = {
        "id": iid,
        "version": ver,
        "timestamp": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "type": item.get("type"),
        "model_id": item.get("model_id"),
        "text": item.get("text"),
        "prompt": item.get("prompt"),
        "source_audio": item.get("source_audio"),
        "duration_result_sec": dur,
        "target_path": item.get("target_path"),
    }
    (item_hist_dir / f"{ver}.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    hist_list = [str(v) for v in item.get("history", [])]
    if ver not in hist_list:
        hist_list.append(ver)
    item["history"] = hist_list
    item["active_version"] = ver
    return ver


def ensure_existing_archived(item: dict[str, Any]) -> str | None:
    iid = str(item["id"])
    item_hist_dir = HISTORY_DIR / iid
    if item_hist_dir.exists() and any(item_hist_dir.glob("v*.json")):
        return None
    out_abs = res_to_abs_path(str(item["target_path"]))
    raw_mp3 = RAW_API_CACHE_DIR / f"{iid}.mp3"
    if not out_abs.exists() and not raw_mp3.exists():
        return None
    return archive_item_files(item, raw_mp3 if raw_mp3.exists() else None, out_abs, version_tag="v01")


def generate_single_item(item: dict[str, Any], voices_map: dict[str, Any], api_key: str) -> float:
    iid = str(item["id"])
    kind = str(item["type"])
    RAW_API_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    raw_mp3_path = RAW_API_CACHE_DIR / f"{iid}.mp3"
    ensure_existing_archived(item)

    if kind == "tts":
        char_id = str(item.get("character", ""))
        v_entry = voices_map.get(char_id, {})
        voice_id = str(item.get("voice_id") or v_entry.get("voice_id", ""))
        if not voice_id or voice_id.startswith("PENDING"):
            raise ValueError(f"Character '{char_id}' has no valid voice_id configured in manifest.")
        model_id = str(item.get("model_id", "eleven_v4"))
        payload: dict[str, Any] = {
            "text": str(item["text"]),
            "model_id": model_id,
        }
        if "voice_settings" in item:
            payload["voice_settings"] = item["voice_settings"]
        endpoint = f"/v1/text-to-speech/{urllib.parse.quote(voice_id)}?output_format={STARTER_OUTPUT_FORMAT}"
        mp3_bytes = api_post_json_binary(endpoint, payload, api_key)

    elif kind == "sfx":
        loop = bool(item.get("loop", False))
        default_sfx_model = "eleven_text_to_sound_v2" if loop else "eleven_text_to_sound_v3"
        model_id = str(item.get("model_id", default_sfx_model))
        if loop and model_id != "eleven_text_to_sound_v2":
            model_id = "eleven_text_to_sound_v2"
        dur = item.get("duration_seconds")
        if dur is None:
            raise ValueError(f"SFX '{iid}' is missing mandatory 'duration_seconds' (anti-waste rule).")
        payload = {
            "text": str(item["prompt"]),
            "model_id": model_id,
            "duration_seconds": float(dur),
            "loop": loop,
        }
        if "prompt_influence" in item:
            payload["prompt_influence"] = float(item["prompt_influence"])
        endpoint = f"/v1/sound-generation?output_format={STARTER_OUTPUT_FORMAT}"
        mp3_bytes = api_post_json_binary(endpoint, payload, api_key)

    elif kind == "sts":
        char_id = str(item.get("character", ""))
        v_entry = voices_map.get(char_id, {})
        voice_id = str(item.get("voice_id") or v_entry.get("voice_id", ""))
        if not voice_id or voice_id.startswith("PENDING"):
            raise ValueError(f"Character '{char_id}' has no valid voice_id configured in manifest.")
        src_rel = str(item["source_audio"])
        src_abs = res_to_abs_path(src_rel)
        if not src_abs.exists():
            raise FileNotFoundError(f"STS raw source audio not found: {src_rel}")
        compat_src = ensure_sts_compatible_input(src_abs, iid)
        model_id = str(item.get("model_id", "eleven_multilingual_sts_v2"))
        remove_bg = bool(item.get("remove_background_noise", True))
        mp3_bytes = api_post_multipart_sts(voice_id, compat_src, model_id, remove_bg, api_key)

    else:
        raise ValueError(f"Unsupported item type '{kind}' on '{iid}'.")

    raw_mp3_path.write_bytes(mp3_bytes)
    out_abs = res_to_abs_path(str(item["target_path"]))
    post_mode = str(item.get("post_process", "wav_bark_trim" if kind in ("tts", "sts") else "wav_sfx_trim"))
    dur = run_ffmpeg_post_process(raw_mp3_path, out_abs, post_mode)
    if dur > 0.0:
        item["duration_result_sec"] = round(dur, 3)
    ver = archive_item_files(item, raw_mp3_path, out_abs)
    print(f"  [history] Archived as {ver} in raw_assets/audio_history/{iid}/")
    return dur


def print_subscription_banner(api_key: str) -> None:
    sub = fetch_subscription(api_key)
    if not sub:
        print("[Account] Could not read live subscription balance (missing key or user_read permission).")
        return
    used = int(sub.get("character_count", 0))
    limit = int(sub.get("character_limit", 0))
    rem = limit - used
    print(f"[Account] Tier: {sub.get('tier')} ({sub.get('status')}) | Used: {used:,} / {limit:,} | Remaining: {rem:,} credits")


def main() -> int:
    parser = argparse.ArgumentParser(description="Trixie ElevenLabs Audio Generator CLI")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST, help="Path to audio_manifest.json")
    parser.add_argument("--dry-run", action="store_true", help="Estimate credits without calling generation endpoints")
    parser.add_argument("--credits", action="store_true", help="Print live remaining credits and exit")
    parser.add_argument("--list-voices", action="store_true", help="List saved/custom ElevenLabs voices (name -> voice_id) at 0 credits")
    parser.add_argument("--id", nargs="+", help="Generate only specific manifest item IDs")
    parser.add_argument("--character", type=str, help="Filter items by character ID")
    parser.add_argument("--type", choices=["sfx", "tts", "sts"], help="Filter items by generation flow")
    parser.add_argument("--only-pending", action="store_true", help="Process pending/regen_requested items (default behavior)")
    parser.add_argument("--reprocess-cached", action="store_true", help="Re-run ffmpeg post-processing from cached raw MP3s (0 credits)")
    parser.add_argument("--backup-current", action="store_true", help="Archive existing un-versioned clips into raw_assets/audio_history/ as v01 (0 credits)")
    parser.add_argument("--history", nargs="*", metavar="ID", help="List archived versions for all or specific item IDs (0 credits)")
    parser.add_argument("--restore", nargs=2, metavar=("ID", "VERSION"), help="Restore an archived version (e.g. --restore vo_trixie_normal_01 v01) at 0 credits")
    parser.add_argument("--approve", nargs="+", help="Mark item IDs as 'approved' in manifest")
    parser.add_argument("--force", action="store_true", help="Force regeneration even if already generated/approved")
    args = parser.parse_args()

    api_key = load_api_key()
    if args.credits:
        if not api_key:
            print("ERROR: ELEVENLABS_API_KEY not found in .env or environment.", file=sys.stderr)
            return 1
        print_subscription_banner(api_key)
        return 0

    if args.list_voices:
        if not api_key:
            print("ERROR: ELEVENLABS_API_KEY not found in .env or environment.", file=sys.stderr)
            return 1
        res = api_get_json("/v2/voices?page_size=50", api_key)
        voices = res.get("voices", []) if isinstance(res, dict) else []
        custom = [v for v in voices if v.get("category") != "premade"]
        if not custom:
            print("No custom/saved voices found.")
            return 0
        print("Saved ElevenLabs Voices:")
        for v in custom:
            print(f"  - {str(v.get('name', 'Unnamed')):28s} | {v.get('voice_id')} ({v.get('category')})")
        return 0

    if not args.manifest.exists():
        print(f"ERROR: Manifest not found at {args.manifest}", file=sys.stderr)
        return 1

    manifest = load_manifest(args.manifest)

    if args.backup_current:
        backed = 0
        for item in manifest.get("items", []):
            ver = ensure_existing_archived(item)
            if ver:
                print(f"  [backup] {item['id']} -> {ver}")
                backed += 1
        save_manifest(args.manifest, manifest)
        print(f"Backed up {backed} item(s) into raw_assets/audio_history/.")
        return 0

    if args.history is not None:
        filter_ids = set(args.history) if args.history else None
        for item in manifest.get("items", []):
            iid = str(item.get("id", ""))
            if filter_ids is not None and iid not in filter_ids:
                continue
            item_hist_dir = HISTORY_DIR / iid
            metas = sorted(item_hist_dir.glob("v*.json")) if item_hist_dir.exists() else []
            active_ver = item.get("active_version", "-")
            print(f"{iid} (status={item.get('status')}, active={active_ver}):")
            if not metas:
                print("  (no archived versions)")
                continue
            for mf in metas:
                m = json.loads(mf.read_text(encoding="utf-8"))
                label = m.get("text") or m.get("prompt") or m.get("source_audio") or ""
                dur_s = m.get("duration_result_sec")
                dur_txt = f"{dur_s:.2f}s" if isinstance(dur_s, (int, float)) else "-"
                marker = " *ACTIVE*" if m.get("version") == active_ver else ""
                print(f"  - {m.get('version')} | {dur_txt:>5s} | {label}{marker}")
        return 0

    if args.restore:
        iid, ver = args.restore
        target_item = next((it for it in manifest.get("items", []) if it.get("id") == iid), None)
        if target_item is None:
            print(f"ERROR: Item '{iid}' not found in manifest.", file=sys.stderr)
            return 1
        out_abs = res_to_abs_path(str(target_item["target_path"]))
        hist_dir = HISTORY_DIR / iid
        hist_audio = hist_dir / f"{ver}{out_abs.suffix}"
        if not hist_audio.exists():
            print(f"ERROR: Archived file not found: {hist_audio}", file=sys.stderr)
            return 1
        out_abs.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(hist_audio, out_abs)
        hist_mp3 = hist_dir / f"{ver}.mp3"
        if hist_mp3.exists():
            RAW_API_CACHE_DIR.mkdir(parents=True, exist_ok=True)
            shutil.copy2(hist_mp3, RAW_API_CACHE_DIR / f"{iid}.mp3")
        hist_meta = hist_dir / f"{ver}.json"
        if hist_meta.exists():
            m = json.loads(hist_meta.read_text(encoding="utf-8"))
            if m.get("duration_result_sec") is not None:
                target_item["duration_result_sec"] = m["duration_result_sec"]
            for field in ("text", "prompt", "source_audio"):
                if m.get(field) is not None:
                    target_item[field] = m[field]
        target_item["active_version"] = ver
        save_manifest(args.manifest, manifest)
        print(f"Restored {iid} -> {ver} ({target_item['target_path']})")
        return 0

    if args.approve:
        approve_set = set(args.approve)
        count = 0
        for item in manifest.get("items", []):
            if item.get("id") in approve_set:
                item["status"] = "approved"
                count += 1
        save_manifest(args.manifest, manifest)
        print(f"Marked {count} item(s) as 'approved'.")
        return 0

    if args.reprocess_cached:
        items = select_items(manifest, args.id, args.character, args.type, force=True)
        for item in items:
            iid = str(item["id"])
            raw_mp3 = RAW_API_CACHE_DIR / f"{iid}.mp3"
            if not raw_mp3.exists():
                print(f"  [skip] No cached MP3 for {iid}")
                continue
            out_abs = res_to_abs_path(str(item["target_path"]))
            mode = str(item.get("post_process", "wav_bark_trim"))
            dur = run_ffmpeg_post_process(raw_mp3, out_abs, mode)
            if dur > 0.0:
                item["duration_result_sec"] = round(dur, 3)
            active_ver = str(item.get("active_version", ""))
            if active_ver:
                hist_dir = HISTORY_DIR / iid
                hist_dir.mkdir(parents=True, exist_ok=True)
                shutil.copy2(out_abs, hist_dir / f"{active_ver}{out_abs.suffix}")
                meta_path = hist_dir / f"{active_ver}.json"
                if meta_path.exists() and dur > 0.0:
                    m = json.loads(meta_path.read_text(encoding="utf-8"))
                    m["duration_result_sec"] = round(dur, 3)
                    meta_path.write_text(json.dumps(m, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print(f"  [reprocessed] {iid} -> {item['target_path']} ({dur:.2f}s)")
        save_manifest(args.manifest, manifest)
        return 0

    items = select_items(manifest, args.id, args.character, args.type, force=args.force)
    if not items:
        print("No matching items to process (all generated/approved or none pending).")
        return 0

    print_subscription_banner(api_key)
    print(f"\nBatch Plan ({len(items)} file(s)):")
    total_est = 0
    for item in items:
        est = estimate_item_credits(item)
        item["estimated_credits"] = est
        total_est += est
        label = item.get("text") or item.get("prompt") or item.get("source_audio") or ""
        print(f"  - [{item.get('type','?').upper():3s}] {item['id']:32s} | ~{est:4d} cred | {label}")
    print(f"Total Estimated Cost: ~{total_est:,} credits\n")

    if args.dry_run:
        save_manifest(args.manifest, manifest)
        return 0

    if not api_key:
        print("ERROR: ELEVENLABS_API_KEY missing in .env. Aborting.", file=sys.stderr)
        return 1

    voices_map = manifest.get("voices", {})
    generated_ok = 0
    for idx, item in enumerate(items):
        iid = str(item["id"])
        print(f"[{idx + 1}/{len(items)}] Generating {iid}...")
        dur = generate_single_item(item, voices_map, api_key)
        item["status"] = "generated"
        if dur > 0.0:
            item["duration_result_sec"] = round(dur, 3)
            print(f"  -> Saved {item['target_path']} (trimmed WAV: {dur:.2f}s)")
        else:
            print(f"  -> Saved {item['target_path']}")
        save_manifest(args.manifest, manifest)
        generated_ok += 1
        if idx + 1 < len(items):
            time.sleep(0.35)

    print(f"\nCompleted {generated_ok}/{len(items)} item(s).")
    print_subscription_banner(api_key)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
