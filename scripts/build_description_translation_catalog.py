#!/usr/bin/env python3
"""Build the bundled skill-description translation catalog.

The app treats this catalog as read-only product data. Manual in-app
translation remains a fallback for new or changed descriptions that are not
covered by this generated file.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import hashlib
import html
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


TRANSLATOR_VERSION = "description-v2"
DEFAULT_LOCALES = ["en", "zh-Hans", "zh-Hant", "ja", "ko", "fr", "de", "es"]
DEFAULT_OUTPUT = Path("SkillsManager/Resources/description-translations.json")


LOCALE_NAMES = {
    "zh-Hans": "Simplified Chinese",
    "zh-Hant": "Traditional Chinese",
    "ja": "Japanese",
    "ko": "Korean",
    "fr": "French",
    "de": "German",
    "es": "Spanish",
}

SIMPLIFIED_MARKERS = set("这为会来过对经个们现发后实还样进开关问题学国时说没给让从将门间与无见电车长马风东话处声点买卖体网线云台页机级尽变边于优简译广气书区师数应论认设请识读写")
TRADITIONAL_MARKERS = set("這為會來過對經個們現發後實還樣進開關問題學國時說沒給讓從將門間與無見電車長馬風東話處聲點買賣體網線雲臺頁機級盡變邊於優簡譯廣氣書區師數應論認設請識讀寫")


def normalized_locale(locale: str) -> str:
    locale = locale.strip().replace("_", "-")
    aliases = {
        "zh": "zh-Hans",
        "zh-cn": "zh-Hans",
        "zh-hans-cn": "zh-Hans",
        "zh-tw": "zh-Hant",
        "zh-hant-tw": "zh-Hant",
    }
    return aliases.get(locale.lower(), locale)


def detected_source_locale(text: str) -> str:
    han = kana = hangul = simplified = traditional = 0
    for char in text:
        code = ord(char)
        if 0x3040 <= code <= 0x30FF:
            kana += 1
        elif 0xAC00 <= code <= 0xD7AF or 0x1100 <= code <= 0x11FF or 0x3130 <= code <= 0x318F:
            hangul += 1
        elif 0x3400 <= code <= 0x4DBF or 0x4E00 <= code <= 0x9FFF or 0xF900 <= code <= 0xFAFF:
            han += 1
            if char in SIMPLIFIED_MARKERS:
                simplified += 1
            if char in TRADITIONAL_MARKERS:
                traditional += 1

    if kana >= 2:
        return "ja"
    if hangul >= 2:
        return "ko"
    if han >= 4:
        return "zh-Hant" if traditional > simplified else "zh-Hans"
    return "en"


def cache_key(source_text: str, source_locale: str, target_locale: str) -> str:
    digest = hashlib.sha256(source_text.encode("utf-8")).hexdigest()
    return f"{digest}|{normalized_locale(source_locale).lower()}|{normalized_locale(target_locale).lower()}|{TRANSLATOR_VERSION}"


def request_text(url: str, timeout: int = 30) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "skills-manager-catalog-builder"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8", errors="replace")


def strip_tags(value: str) -> str:
    value = re.sub(r"<script[\s\S]*?</script>", "", value)
    value = re.sub(r"<style[\s\S]*?</style>", "", value)
    value = re.sub(r"<[^>]+>", " ", value)
    value = html.unescape(value)
    return re.sub(r"\s+", " ", value).strip()


def first_match(text: str, pattern: str, group: int = 1) -> str | None:
    match = re.search(pattern, text)
    return match.group(group) if match else None


def extract_balanced_json_section(text: str, marker: str, opening: str, closing: str) -> str | None:
    start_marker = text.find(marker)
    if start_marker < 0:
        return None
    start = text.find(opening, start_marker + len(marker))
    if start < 0:
        return None

    depth = 0
    in_string = False
    escaped = False
    for index in range(start, len(text)):
        char = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        else:
            if char == '"':
                in_string = True
            elif char == opening:
                depth += 1
            elif char == closing:
                depth -= 1
                if depth == 0:
                    return text[start : index + 1]
    return None


def fetch_skills_sh_entries(max_workers: int) -> list[dict[str, str]]:
    directory_html = request_text("https://skills.sh/")
    raw_entries = extract_balanced_json_section(directory_html, '\\"initialSkills\\":', "[", "]")
    if raw_entries:
        raw_entries = raw_entries.replace('\\"', '"')
        try:
            directory_entries = json.loads(raw_entries)
        except json.JSONDecodeError:
            directory_entries = []
    else:
        directory_entries = []

    if not directory_entries:
        direct_pattern = r'\{"source":"([^"]+)","skillId":"([^"]+)","name":"([^"]+)","installs":(\d+)\}'
        escaped_pattern = r'\{\\"source\\":\\"([^\\]+)\\",\\"skillId\\":\\"([^\\]+)\\",\\"name\\":\\"([^\\]+)\\",\\"installs\\":(\d+)\}'
        directory_entries = [
            {"source": source, "skillId": skill_id, "name": name}
            for pattern in (direct_pattern, escaped_pattern)
            for source, skill_id, name, _installs in re.findall(pattern, directory_html)
        ]

    def load_detail(entry: dict[str, Any]) -> dict[str, str] | None:
        source = str(entry.get("source", "")).strip()
        skill_id = str(entry.get("skillId", "")).strip()
        if not source or not skill_id:
            return None
        detail_url = f"https://skills.sh/{urllib.parse.quote(source, safe='/')}/{urllib.parse.quote(skill_id)}"
        try:
            detail_html = request_text(detail_url)
        except urllib.error.URLError as error:
            print(f"[catalog] detail failed {source}:{skill_id}: {error}", file=sys.stderr)
            return None

        summary_html = first_match(
            detail_html,
            r'<div class="prose[^"]*">([\s\S]*?)</div></div></div><div class="bg-background"><div class="flex items-center[^>]*"><span>SKILL\.md</span>',
        )
        summary = strip_tags(summary_html) if summary_html else None
        if not summary:
            readme_html = first_match(
                detail_html,
                r'<span>SKILL\.md</span></div><div class="prose[^"]*">([\s\S]*?)</div></div></div>',
            )
            paragraph = first_match(readme_html or "", r"<p>([\s\S]*?)</p>")
            summary = strip_tags(paragraph or "")

        if not summary:
            return None
        return {
            "id": f"{source}:{skill_id}",
            "sourceLocale": detected_source_locale(summary),
            "sourceText": summary,
        }

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        return [item for item in executor.map(load_detail, directory_entries) if item]


def read_input_entries(path: Path) -> list[dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        return list(payload.get("items") or payload.get("entries") or [])
    raise ValueError("Input must be a JSON array or an object with items/entries.")


def load_existing_catalog(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"version": TRANSLATOR_VERSION, "generatedAt": None, "locales": DEFAULT_LOCALES, "entries": {}}
    payload = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(payload, dict) and isinstance(payload.get("entries"), dict):
        return payload
    if isinstance(payload, dict):
        return {"version": TRANSLATOR_VERSION, "generatedAt": None, "locales": DEFAULT_LOCALES, "entries": payload}
    raise ValueError(f"Unsupported catalog shape: {path}")


def ollama_translate(base_url: str, model: str, text: str, source_locale: str, target_locale: str) -> str:
    target_name = LOCALE_NAMES.get(target_locale, target_locale)
    prompt = (
        "/no_think\n"
        f"Translate this short skill description from {source_locale} to {target_name}.\n"
        "Return only the translated description. Preserve product names and CLI command names.\n\n"
        f"{text}"
    )
    payload = {
        "model": model,
        "stream": False,
        "think": False,
        "messages": [{"role": "user", "content": prompt}],
        "options": {"temperature": 0, "num_ctx": 2048, "num_predict": 256},
    }
    url = base_url.rstrip("/") + "/api/chat"
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(request, timeout=180) as response:
        body = json.loads(response.read().decode("utf-8"))
    translated = str(body.get("message", {}).get("content", "")).strip()
    return re.sub(r"<think>[\s\S]*?</think>", "", translated).strip()


def openai_compatible_request(base_url: str, api_key: str, payload: dict[str, Any]) -> dict[str, Any]:
    url = base_url.rstrip("/")
    if not url.endswith("/chat/completions"):
        url += "/chat/completions" if url.endswith("/v1") else "/v1/chat/completions"
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {error.code} from translation provider: {body[:500]}") from error


def openai_compatible_translate(
    base_url: str,
    api_key: str,
    model: str,
    text: str,
    source_locale: str,
    target_locale: str,
) -> str:
    target_name = LOCALE_NAMES.get(target_locale, target_locale)
    payload = {
        "model": model,
        "temperature": 0,
        "stream": False,
        "messages": [
            {
                "role": "system",
                "content": "You translate short software skill descriptions. Return only the translation.",
            },
            {
                "role": "user",
                "content": (
                    f"Translate from {source_locale} to {target_name}. "
                    "Preserve product names and CLI command names.\n\n"
                    f"{text}"
                ),
            },
        ],
    }
    body = openai_compatible_request(base_url, api_key, payload)
    return str(body["choices"][0]["message"]["content"]).strip()


def openai_compatible_translate_locales(
    base_url: str,
    api_key: str,
    model: str,
    text: str,
    source_locale: str,
    target_locales: list[str],
) -> dict[str, str]:
    locale_labels = {locale: LOCALE_NAMES.get(locale, locale) for locale in target_locales}
    payload = {
        "model": model,
        "temperature": 0,
        "stream": False,
        "response_format": {"type": "json_object"},
        "messages": [
            {
                "role": "system",
                "content": (
                    "You translate short software skill descriptions. "
                    "Return only valid minified JSON with locale codes as keys and translations as values."
                ),
            },
            {
                "role": "user",
                "content": (
                    f"Translate from {source_locale} into these locales: {json.dumps(locale_labels, ensure_ascii=False)}.\n"
                    "Preserve product names, CLI command names, code identifiers, and brand names.\n"
                    "Return JSON only. Do not include markdown fences or explanations.\n\n"
                    f"{text}"
                ),
            },
        ],
    }
    body = openai_compatible_request(base_url, api_key, payload)
    raw = str(body["choices"][0]["message"]["content"]).strip()
    if raw.startswith("```"):
        raw = re.sub(r"^```(?:json)?\s*", "", raw)
        raw = re.sub(r"\s*```$", "", raw)
    parsed = json.loads(raw)
    if not isinstance(parsed, dict):
        raise ValueError("Batch translation response was not a JSON object.")
    return {locale: str(parsed.get(locale, "")).strip() for locale in target_locales}


def translated_values_from_entry(entry: dict[str, Any]) -> dict[str, str]:
    values = entry.get("translations")
    return values if isinstance(values, dict) else {}


def write_catalog(path: Path, entries: dict[str, str], locales: list[str]) -> None:
    output = {
        "version": TRANSLATOR_VERSION,
        "generatedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "locales": locales,
        "entries": dict(sorted(entries.items())),
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(output, ensure_ascii=False, indent=2, sort_keys=False) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, help="JSON entries with sourceText/sourceLocale and optional translations.")
    parser.add_argument("--fetch-skills-sh", action="store_true", help="Fetch current skills.sh summaries as source entries.")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--locales", nargs="+", default=DEFAULT_LOCALES)
    parser.add_argument("--provider", choices=["none", "ollama", "openai-compatible"], default="none")
    parser.add_argument("--base-url", default="http://127.0.0.1:11434")
    parser.add_argument("--model")
    parser.add_argument("--api-key-env", default="DEEPSEEK_API_KEY")
    parser.add_argument("--batch-locales", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--max-workers", type=int, default=8)
    parser.add_argument("--sleep", type=float, default=0.0, help="Seconds to sleep between translation requests.")
    parser.add_argument("--save-every", type=int, default=10, help="Persist catalog after this many new entries.")
    parser.add_argument("--stop-on-error", action=argparse.BooleanOptionalAction, default=False)
    args = parser.parse_args()

    if args.fetch_skills_sh:
        source_entries = fetch_skills_sh_entries(max_workers=args.max_workers)
    elif args.input:
        source_entries = read_input_entries(args.input)
    else:
        parser.error("Pass --fetch-skills-sh or --input.")

    if args.provider != "none" and not args.model:
        parser.error("--model is required when provider is not none.")
    api_key = os.environ.get(args.api_key_env, "").strip()
    if args.provider == "openai-compatible" and not api_key:
        parser.error(f"${args.api_key_env} is required for openai-compatible provider.")

    catalog = load_existing_catalog(args.output)
    entries: dict[str, str] = dict(catalog.get("entries") or {})
    target_locales = [normalized_locale(locale) for locale in args.locales]

    total = 0
    processed = 0
    for source_entry in source_entries:
        processed += 1
        source_text = str(source_entry.get("sourceText") or "").strip()
        source_locale = normalized_locale(str(source_entry.get("sourceLocale") or "en"))
        if not source_text:
            continue
        existing_translations = translated_values_from_entry(source_entry)
        missing_locales = [
            target_locale
            for target_locale in target_locales
            if normalized_locale(target_locale).lower() != normalized_locale(source_locale).lower()
            and cache_key(source_text, source_locale, target_locale) not in entries
            and not str(existing_translations.get(target_locale) or "").strip()
        ]

        if args.provider == "openai-compatible" and args.batch_locales and missing_locales:
            try:
                translations = openai_compatible_translate_locales(
                    args.base_url,
                    api_key,
                    args.model,
                    source_text,
                    source_locale,
                    missing_locales,
                )
            except Exception as error:
                print(f"[catalog] translation failed {source_entry.get('id', '')}: {error}", file=sys.stderr)
                if args.stop_on_error:
                    raise
                translations = {}
                for target_locale in missing_locales:
                    try:
                        translations[target_locale] = openai_compatible_translate(
                            args.base_url,
                            api_key,
                            args.model,
                            source_text,
                            source_locale,
                            target_locale,
                        )
                    except Exception as fallback_error:
                        print(
                            f"[catalog] fallback failed {target_locale} {source_entry.get('id', '')}: {fallback_error}",
                            file=sys.stderr,
                        )
            for target_locale, translated in translations.items():
                key = cache_key(source_text, source_locale, target_locale)
                if translated and translated != source_text:
                    entries[key] = translated
                    total += 1
                    print(f"[catalog] + {target_locale} {source_entry.get('id', '')}".strip())
                    if args.save_every > 0 and total % args.save_every == 0:
                        write_catalog(args.output, entries, DEFAULT_LOCALES)
            if args.sleep:
                time.sleep(args.sleep)

        for target_locale in target_locales:
            if normalized_locale(target_locale).lower() == normalized_locale(source_locale).lower():
                continue
            key = cache_key(source_text, source_locale, target_locale)
            if key in entries:
                continue

            translated = str(existing_translations.get(target_locale) or "").strip()
            if not translated and args.provider == "ollama":
                translated = ollama_translate(args.base_url, args.model, source_text, source_locale, target_locale)
            elif not translated and args.provider == "openai-compatible":
                if args.batch_locales:
                    continue
                translated = openai_compatible_translate(
                    args.base_url,
                    api_key,
                    args.model,
                    source_text,
                    source_locale,
                    target_locale,
                )

            if translated and translated != source_text:
                entries[key] = translated
                total += 1
                print(f"[catalog] + {target_locale} {source_entry.get('id', '')}".strip())
                if args.save_every > 0 and total % args.save_every == 0:
                    write_catalog(args.output, entries, DEFAULT_LOCALES)
                if args.sleep:
                    time.sleep(args.sleep)

    write_catalog(args.output, entries, DEFAULT_LOCALES)
    print(f"[catalog] wrote {len(entries)} entries ({total} new) -> {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
