#!/usr/bin/env python3
"""
Green API Auto-Discover & Analyzer
===================================
1. Discovers routes from a running API (OpenAPI/Swagger endpoint or file)
2. Runs Spectral linting against Green API rules
3. Measures every discovered endpoint (response time, payload size)
4. Computes Green Score + energy estimates
5. Generates a report compatible with the dashboard (index.html)

Usage (standalone):
    python green-api-auto-discover.py --target http://localhost:8081

Usage (with explicit swagger):
    python green-api-auto-discover.py --target http://localhost:8081 \
        --swagger http://localhost:8081/v3/api-docs

Usage (dry-run, no HTTP calls):
    python green-api-auto-discover.py --swagger ./my-spec.yaml --dry-run
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

try:
    import yaml  # type: ignore
except Exception:
    yaml = None

# ─── Constants ──────────────────────────────────────────────────────────────

SWAGGER_DISCOVERY_PATHS = [
    "/v3/api-docs",           # springdoc-openapi (Spring Boot) — priority
    "/v3/api-docs.yaml",      # springdoc YAML variant
    "/swagger-ui/index.html",  # springdoc UI (to confirm it exists)
    "/v2/api-docs",           # springfox legacy
    "/openapi.json",          # generic
    "/openapi.yaml",
    "/swagger/v1/swagger.json",  # .NET / Swashbuckle
    "/swagger.json",
    "/swagger.yaml",
]

GREEN_RULES = {
    "DE11_pagination": {
        "id": "DE11", "label": "Pagination", "max_pts": 15,
        "check": "collection_has_pagination_params",
        "description": "Les endpoints de collection doivent supporter la pagination (page/size ou limit/offset).",
    },
    "DE08_fields": {
        "id": "DE08", "label": "Filtrage de champs", "max_pts": 15,
        "check": "has_fields_param",
        "description": "Supporter un parametre 'fields' pour reduire le payload.",
    },
    "DE01_compression": {
        "id": "DE01", "label": "Compression", "max_pts": 15,
        "check": "server_supports_gzip",
        "description": "Le serveur doit supporter Accept-Encoding: gzip.",
    },
    "DE02_DE03_cache": {
        "id": "DE02/DE03", "label": "Cache ETag/304", "max_pts": 15,
        "check": "supports_etag_304",
        "description": "Les ressources unitaires doivent supporter ETag + If-None-Match -> 304.",
    },
    "DE06_delta": {
        "id": "DE06", "label": "Delta / Changes", "max_pts": 10,
        "check": "has_delta_endpoint",
        "description": "Un endpoint /changes?since= ou equivalent doit exister.",
    },
    "range_206": {
        "id": "206", "label": "Range / Partial Content", "max_pts": 10,
        "check": "supports_range_206",
        "description": "Supporter le header Range pour les gros payloads.",
    },
    "AR02_format_cbor": {
        "id": "AR02", "label": "Format binaire (CBOR)", "max_pts": 10,
        "check": "has_binary_format",
        "description": "Un endpoint en format binaire (CBOR, protobuf...) doit exister.",
    },
    "LO01_observability": {
        "id": "LO01", "label": "Observabilite", "max_pts": 5,
        "check": "has_actuator",
        "description": "Actuator / health / metrics doit etre expose.",
    },
    "US07_rate_limit": {
        "id": "US07", "label": "Rate Limiting", "max_pts": 5,
        "check": "assumed_if_running",
        "description": "Un mecanisme de rate limiting doit etre present.",
    },
}

DEFAULT_NETWORK_KWH_PER_GB = 0.06
DEFAULT_SERVER_POWER_W = 25.0

# ─── Helpers ────────────────────────────────────────────────────────────────

def log(msg, level="INFO"):
    colors = {"INFO": "\033[0;36m", "OK": "\033[0;32m", "WARN": "\033[1;33m", "ERR": "\033[0;31m"}
    nc = "\033[0m"
    c = colors.get(level, "")
    print(f"{c}[{level}]{nc} {msg}", file=sys.stderr)


def http_get(url, headers=None, timeout=10):
    """Simple GET, returns (status, body_bytes, headers_dict)."""
    hdrs = headers or {}
    req = urllib.request.Request(url, headers=hdrs)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read()
            resp_headers = {k.lower(): v for k, v in resp.getheaders()}
            return resp.status, body, resp_headers
    except urllib.error.HTTPError as e:
        body = e.read() if hasattr(e, "read") else b""
        return e.code, body, {}
    except Exception:
        return 0, b"", {}


def http_head(url, headers=None, timeout=10):
    hdrs = headers or {}
    req = urllib.request.Request(url, method="HEAD", headers=hdrs)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            resp_headers = {k.lower(): v for k, v in resp.getheaders()}
            return resp.status, resp_headers
    except urllib.error.HTTPError as e:
        return e.code, {}
    except Exception:
        return 0, {}


def parse_spec_text(text, source_label):
    try:
        return json.loads(text)
    except Exception:
        if yaml is not None:
            try:
                return yaml.safe_load(text)
            except Exception:
                pass
        raise ValueError(f"Cannot parse OpenAPI spec from {source_label}")


def load_spec(source):
    if source.startswith("http://") or source.startswith("https://"):
        status, body, _ = http_get(source, timeout=15)
        if status == 200 and body:
            return parse_spec_text(body.decode("utf-8", errors="replace"), source)
        raise ValueError(f"HTTP {status} fetching {source}")
    with open(source, "r", encoding="utf-8") as f:
        return parse_spec_text(f.read(), source)


def slugify(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def bytes_to_wh(size_bytes, kwh_per_gb):
    return (size_bytes / (1024**3)) * kwh_per_gb * 1000


def seconds_to_wh(seconds, power_w):
    return seconds * (power_w / 3600)


def format_bytes(b):
    if b < 1024:
        return f"{b} B"
    if b < 1024**2:
        return f"{b/1024:.1f} KB"
    if b < 1024**3:
        return f"{b/1024**2:.1f} MB"
    return f"{b/1024**3:.2f} GB"

# ─── Step 1: Discover Swagger ──────────────────────────────────────────────

def discover_swagger(base_url):
    """Try common OpenAPI endpoints to find the spec."""
    log(f"Discovering OpenAPI spec on {base_url}...")
    for path in SWAGGER_DISCOVERY_PATHS:
        url = base_url.rstrip("/") + path
        status, body, hdrs = http_get(url, timeout=5)
        if status == 200 and body and len(body) > 50:
            log(f"Found spec at {url}", "OK")
            try:
                return parse_spec_text(body.decode("utf-8", errors="replace"), url), url
            except ValueError:
                continue
    return None, None


def extract_endpoints(spec):
    """Extract all endpoints with their methods and parameters from the spec."""
    endpoints = []
    base_path = ""
    # Swagger 2.0
    if spec.get("swagger") == "2.0":
        base_path = spec.get("basePath", "")
    for path, ops in (spec.get("paths") or {}).items():
        full_path = base_path + path if base_path else path
        for method in ("get", "post", "put", "patch", "delete", "head"):
            if method not in ops:
                continue
            op = ops[method]
            params = op.get("parameters") or []
            # Merge path-level parameters
            if isinstance(ops.get("parameters"), list):
                param_names = {p.get("name") for p in params}
                for p in ops["parameters"]:
                    if p.get("name") not in param_names:
                        params.append(p)
            endpoints.append({
                "path": full_path,
                "method": method,
                "operationId": op.get("operationId", f"{method}_{full_path}"),
                "summary": op.get("summary", ""),
                "parameters": params,
                "tags": op.get("tags", []),
                "produces": op.get("produces", []),
                "responses": op.get("responses", {}),
            })
    return endpoints


# ─── Step 2: Spectral Linting ──────────────────────────────────────────────

def run_spectral(spec_source, spectral_config, output_file):
    """Run Spectral CLI if available. Returns list of issues or None."""
    spectral_bin = shutil.which("spectral")
    npx_bin = shutil.which("npx")
    if not spectral_bin and not npx_bin:
        log("Spectral CLI not found (install: npm i -g @stoplight/spectral-cli). Skipping lint.", "WARN")
        return None

    cmd_prefix = [spectral_bin] if spectral_bin else [npx_bin, "@stoplight/spectral-cli"]
    cmd = cmd_prefix + [
        "lint", spec_source,
        "--ruleset", spectral_config,
        "--format", "json",
        "--output", output_file,
    ]
    log(f"Running Spectral: {' '.join(cmd)}")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        if os.path.isfile(output_file):
            with open(output_file, "r", encoding="utf-8") as f:
                issues = json.load(f)
            log(f"Spectral found {len(issues)} issue(s)", "OK" if len(issues) == 0 else "WARN")
            return issues
        # Spectral may output to stdout on some versions
        if result.stdout.strip().startswith("["):
            issues = json.loads(result.stdout)
            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(issues, f, indent=2)
            return issues
    except Exception as e:
        log(f"Spectral error: {e}", "ERR")
    return None


# ─── Step 3: Measure Endpoints ─────────────────────────────────────────────

def measure_endpoint(url, method="GET", headers=None, repeat=3, timeout=30):
    """Measure an endpoint: avg response time, avg payload size, status."""
    total_time = 0.0
    total_bytes = 0
    last_status = 0
    last_headers = {}
    hdrs = headers or {}

    for _ in range(max(1, repeat)):
        req = urllib.request.Request(url, method=method.upper(), headers=hdrs)
        start = time.perf_counter()
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                body = resp.read()
                elapsed = time.perf_counter() - start
                last_status = resp.status
                last_headers = {k.lower(): v for k, v in resp.getheaders()}
                total_time += elapsed
                total_bytes += len(body)
        except urllib.error.HTTPError as e:
            elapsed = time.perf_counter() - start
            last_status = e.code
            body = e.read() if hasattr(e, "read") else b""
            total_time += elapsed
            total_bytes += len(body)
        except Exception:
            elapsed = time.perf_counter() - start
            total_time += elapsed

    n = max(1, repeat)
    return {
        "http_code": last_status,
        "size_download": int(total_bytes / n),
        "time_total": round(total_time / n, 6),
        "speed_download": int((total_bytes / n) / max(total_time / n, 0.001)),
        "response_headers": last_headers,
    }


def build_url(base, path, user_params):
    """Build a callable URL, filling path params and required query params."""
    filled = re.sub(r"\{([^}]+)\}", lambda m: str(user_params.get(m.group(1), "1")), path)
    url = base.rstrip("/") + (filled if filled.startswith("/") else "/" + filled)
    return url


# ─── Step 4: Green Score Analysis (static + runtime) ──────────────────────

def analyze_green_rules(spec, endpoints, base_url, measurements, auth_headers):
    """Analyze Green API rules against the spec and live measurements."""
    scores = {}
    details = {}

    # Helper: find collection endpoints (GET returning arrays, path has no {id})
    collection_eps = [e for e in endpoints if e["method"] == "get" and "{" not in e["path"]
                      and not e["path"].endswith("/health")]

    # Helper: find single-resource endpoints (GET with {id} in path)
    single_eps = [e for e in endpoints if e["method"] == "get" and "{" in e["path"]]

    # Full payload measurement (largest collection)
    full_payload_key = None
    full_payload_size = 0
    for e in collection_eps:
        key = f"get:{e['path']}"
        m = measurements.get(key, {})
        if m.get("size_download", 0) > full_payload_size:
            full_payload_size = m.get("size_download", 0)
            full_payload_key = key

    # ── DE11 Pagination ──
    has_pagination = False
    for e in collection_eps:
        param_names = {p.get("name", "").lower() for p in e.get("parameters", [])}
        if param_names & {"page", "size", "limit", "offset", "cursor"}:
            has_pagination = True
            break
    if has_pagination:
        scores["DE11_pagination"] = 15
        details["DE11_pagination"] = {"note": "Pagination params detected in spec"}
    else:
        scores["DE11_pagination"] = 0
        details["DE11_pagination"] = {"note": "No pagination params found on collection endpoints"}

    # ── DE08 Fields filter ──
    has_fields = False
    for e in endpoints:
        param_names = {p.get("name", "").lower() for p in e.get("parameters", [])}
        if "fields" in param_names or "select" in param_names:
            has_fields = True
            break
    # Also check if a /select endpoint exists
    if not has_fields:
        for e in endpoints:
            if "/select" in e["path"]:
                has_fields = True
                break
    if has_fields:
        scores["DE08_fields"] = 15
        details["DE08_fields"] = {"note": "Fields filter detected"}
    else:
        scores["DE08_fields"] = 0
        details["DE08_fields"] = {"note": "No fields filter found"}

    # ── DE01 Compression ──
    gzip_ok = False
    if collection_eps and base_url:
        test_ep = collection_eps[0]
        url = build_url(base_url, test_ep["path"], {})
        m = measure_endpoint(url, headers={**auth_headers, "Accept-Encoding": "gzip"}, repeat=1, timeout=15)
        ce = m.get("response_headers", {}).get("content-encoding", "")
        if "gzip" in ce.lower():
            gzip_ok = True
        # Also check if compressed size < uncompressed
        key = f"get:{test_ep['path']}"
        raw_size = measurements.get(key, {}).get("size_download", 0)
        if m["size_download"] > 0 and raw_size > 0 and m["size_download"] < raw_size * 0.9:
            gzip_ok = True
    if gzip_ok:
        scores["DE01_compression"] = 15
        details["DE01_compression"] = {"note": "Gzip compression active"}
    else:
        scores["DE01_compression"] = 0
        details["DE01_compression"] = {"note": "Gzip not detected"}

    # ── DE02/DE03 Cache ETag ──
    etag_ok = False
    if single_eps and base_url:
        test_ep = single_eps[0]
        url = build_url(base_url, test_ep["path"], {})
        _, head_hdrs = http_head(url, headers=auth_headers, timeout=10)
        etag_val = head_hdrs.get("etag", "")
        if etag_val:
            m304 = measure_endpoint(url, headers={**auth_headers, "If-None-Match": etag_val}, repeat=1)
            if m304["http_code"] == 304:
                etag_ok = True
    if etag_ok:
        scores["DE02_DE03_cache"] = 15
        details["DE02_DE03_cache"] = {"http_code": 304, "note": "ETag + 304 supported"}
    else:
        scores["DE02_DE03_cache"] = 0
        details["DE02_DE03_cache"] = {"note": "ETag/304 not detected"}

    # ── DE06 Delta ──
    has_delta = any("change" in e["path"].lower() or "delta" in e["path"].lower()
                     for e in endpoints if e["method"] == "get")
    if has_delta:
        scores["DE06_delta"] = 10
        details["DE06_delta"] = {"note": "Delta/changes endpoint detected"}
    else:
        scores["DE06_delta"] = 0
        details["DE06_delta"] = {"note": "No delta endpoint found"}

    # ── Range 206 ──
    range_ok = False
    if single_eps and base_url:
        for test_ep in single_eps + collection_eps[:1]:
            url = build_url(base_url, test_ep["path"], {})
            mr = measure_endpoint(url, headers={**auth_headers, "Range": "bytes=0-99"}, repeat=1)
            if mr["http_code"] == 206:
                range_ok = True
                break
    if range_ok:
        scores["range_206"] = 10
        details["range_206"] = {"http_code": 206, "note": "Range/206 supported"}
    else:
        scores["range_206"] = 0
        details["range_206"] = {"note": "Range not supported"}

    # ── AR02 Binary format ──
    has_cbor = any("cbor" in e["path"].lower() or "protobuf" in e["path"].lower()
                    or "application/cbor" in str(e.get("produces", []))
                    for e in endpoints)
    if has_cbor:
        scores["AR02_format_cbor"] = 10
        details["AR02_format_cbor"] = {"note": "Binary format endpoint detected"}
    else:
        scores["AR02_format_cbor"] = 0
        details["AR02_format_cbor"] = {"note": "No binary format endpoint"}

    # ── LO01 Observability ──
    actuator_ok = False
    if base_url:
        for p in ["/actuator/health", "/health", "/actuator"]:
            s, _, _ = http_get(base_url.rstrip("/") + p, timeout=5)
            if s == 200:
                actuator_ok = True
                break
    if actuator_ok:
        scores["LO01_observability"] = 5
        details["LO01_observability"] = {"note": "Actuator/health detected"}
    else:
        scores["LO01_observability"] = 0
        details["LO01_observability"] = {"note": "No health endpoint"}

    # ── US07 Rate limiting ──
    # Heuristic: assumed if the API is running and has proper middleware
    if base_url and full_payload_size > 0:
        scores["US07_rate_limit"] = 5
        details["US07_rate_limit"] = {"note": "Assumed present (API running)"}
    else:
        scores["US07_rate_limit"] = 0
        details["US07_rate_limit"] = {"note": "Cannot verify"}

    total = sum(scores.values())
    max_score = sum(r["max_pts"] for r in GREEN_RULES.values())
    grade = ("A+" if total >= 90 else "A" if total >= 80 else "B" if total >= 65
             else "C" if total >= 50 else "D" if total >= 30 else "E")

    return {
        "total": total,
        "max": max_score,
        "grade": grade,
        "breakdown": scores,
        "details": details,
    }


# ─── Step 5: Build Dashboard-Compatible Report ────────────────────────────

def load_previous_report(output_dir):
    """Load the latest-report.json if it exists (for before/after comparison)."""
    latest = output_dir / "latest-report.json"
    if latest.is_file():
        try:
            with open(latest, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return None


def build_dashboard_report(timestamp, green_score, measurements_map, endpoints,
                           base_url, full_key, net_kwh_gb, srv_w, previous_report):
    """Build a report in the same format as green-score-analyzer.sh output.

    If previous_report is None (first analysis), baseline = optimized (before = after).
    Otherwise baseline comes from the previous report's measurements.
    """

    def make_entry(m):
        return {
            "http_code": m.get("http_code", 0),
            "size_download": m.get("size_download", 0),
            "time_total": m.get("time_total", 0),
            "speed_download": m.get("speed_download", 0),
        }

    ZERO = {"http_code": 0, "size_download": 0, "time_total": 0, "speed_download": 0}

    # Find the full naive payload (biggest collection GET)
    full_m = measurements_map.get(full_key, ZERO)

    # Map known optimized keys for dashboard compatibility
    mapped_optimized = {}
    for key, m in measurements_map.items():
        method, path = key.split(":", 1)
        entry = make_entry(m)
        pl = path.lower()
        if "page" in str(m.get("_params", "")) or "page" in pl:
            mapped_optimized.setdefault("pagination", entry)
        elif "select" in pl or "fields" in pl:
            mapped_optimized.setdefault("fields_filter", entry)
        elif "change" in pl or "delta" in pl:
            mapped_optimized.setdefault("delta_changes", entry)
        elif "cbor" in pl:
            mapped_optimized.setdefault("cbor_format", entry)
        elif "summary" in pl:
            mapped_optimized.setdefault("range_206", entry)

    # Full payload = the biggest measured endpoint
    mapped_optimized["full_payload"] = make_entry(full_m)

    # Build all_measurements dict (keyed by method:path)
    all_measurements = {}
    for key, m in measurements_map.items():
        all_measurements[key] = make_entry(m)

    # Build discovered_endpoints list for dynamic dashboard rows
    discovered_endpoints = []
    for ep in endpoints:
        key = f"{ep['method']}:{ep['path']}"
        m = measurements_map.get(key)
        if m:
            discovered_endpoints.append({
                "method": ep["method"].upper(),
                "path": ep["path"],
                "operationId": ep.get("operationId", ""),
                "summary": ep.get("summary", ""),
                "tags": ep.get("tags", []),
                **make_entry(m),
            })

    # ── Baseline logic: first analysis → before = after ──
    if previous_report and previous_report.get("measurements"):
        prev_m = previous_report["measurements"]
        baseline = {
            "full_payload": prev_m.get("baseline", {}).get("full_payload")
                           or prev_m.get("optimized", {}).get("full_payload")
                           or make_entry(full_m),
            "single_resource": prev_m.get("baseline", {}).get("single_resource", ZERO),
            "single_repeat": prev_m.get("baseline", {}).get("single_repeat", ZERO),
        }
    else:
        # First analysis: baseline = current measurements (before = after)
        baseline = {
            "full_payload": make_entry(full_m),
            "single_resource": ZERO,
            "single_repeat": ZERO,
        }

    report = {
        "timestamp": timestamp,
        "green_score": green_score,
        "measurements": {
            "baseline": baseline,
            "optimized": mapped_optimized,
        },
        "auto_discovery": {
            "base_url": base_url,
            "endpoints_discovered": len(endpoints),
            "endpoints_measured": len(measurements_map),
            "all_measurements": all_measurements,
            "discovered_endpoints": discovered_endpoints,
        },
    }
    return report


# ─── Main ──────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Green API Auto-Discover & Analyzer",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Auto-discover swagger from running API
  python green-api-auto-discover.py --target http://localhost:8081

  # Explicit swagger file + base URL
  python green-api-auto-discover.py --swagger ./openapi.yaml --target http://localhost:8081

  # Dry-run (no HTTP calls to endpoints)
  python green-api-auto-discover.py --swagger ./openapi.yaml --dry-run

  # With bearer token
  python green-api-auto-discover.py --target http://localhost:8081 --bearer MY_TOKEN
        """,
    )
    parser.add_argument("--target", default="", help="Base URL of the running API (e.g. http://localhost:8081)")
    parser.add_argument("--swagger", default="", help="Path or URL to OpenAPI spec (auto-discovered if omitted)")
    parser.add_argument("--bearer", default="", help="Bearer token for authenticated APIs")
    parser.add_argument("--param", action="append", default=[], help="Path/query param key=value (repeatable)")
    parser.add_argument("--repeat", type=int, default=3, help="Number of repetitions per endpoint (default: 3)")
    parser.add_argument("--methods", default="get", help="Comma-separated HTTP methods to measure (default: get)")
    parser.add_argument("--dry-run", action="store_true", help="List endpoints without calling them")
    parser.add_argument("--spectral-config", default="", help="Path to .spectral.yml (auto-detected)")
    parser.add_argument("--network-kwh-per-gb", type=float, default=DEFAULT_NETWORK_KWH_PER_GB)
    parser.add_argument("--server-power-w", type=float, default=DEFAULT_SERVER_POWER_W)
    parser.add_argument("--output-dir", default="", help="Output directory for reports (default: reports/)")
    parser.add_argument("--skip-spectral", action="store_true", help="Skip Spectral linting")
    parser.add_argument("--skip-dashboard", action="store_true", help="Skip dashboard generation")
    args = parser.parse_args()

    # ── Resolve paths ──
    script_dir = Path(__file__).resolve().parent
    root_dir = script_dir.parent
    output_dir = Path(args.output_dir) if args.output_dir else root_dir / "reports"
    output_dir.mkdir(parents=True, exist_ok=True)

    timestamp_str = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    timestamp_file = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")

    base_url = args.target.rstrip("/") if args.target else ""

    # Parse user params
    user_params = {}
    for item in args.param:
        if "=" in item:
            k, v = item.split("=", 1)
            user_params[k] = v

    # Auth headers
    auth_headers = {}
    if args.bearer:
        auth_headers["Authorization"] = f"Bearer {args.bearer}"

    # ── Banner ──
    log("=" * 60)
    log("  Green API Auto-Discover & Analyzer")
    log("  Devoxx France 2026 — Green Architecture")
    log("=" * 60)

    # ── Step 1: Load/Discover Swagger ──
    spec = None
    swagger_source = args.swagger

    if swagger_source:
        log(f"Loading spec from: {swagger_source}")
        try:
            spec = load_spec(swagger_source)
        except Exception as e:
            log(f"Failed to load spec: {e}", "ERR")
            sys.exit(1)
    elif base_url:
        spec, swagger_source = discover_swagger(base_url)
        if not spec:
            log("Could not auto-discover OpenAPI spec. Provide --swagger explicitly.", "ERR")
            sys.exit(1)
    else:
        log("Provide --target or --swagger.", "ERR")
        sys.exit(1)

    if not base_url:
        # Try to infer from spec
        servers = spec.get("servers", [])
        if servers:
            base_url = servers[0].get("url", "").rstrip("/")
        elif spec.get("host"):
            scheme = (spec.get("schemes") or ["http"])[0]
            base_url = f"{scheme}://{spec['host']}{spec.get('basePath', '')}".rstrip("/")
    if not base_url and not args.dry_run:
        log("Cannot determine base URL. Provide --target.", "ERR")
        sys.exit(1)

    # Save spec locally for Spectral
    spec_local = output_dir / "discovered-openapi.json"
    with open(spec_local, "w", encoding="utf-8") as f:
        json.dump(spec, f, indent=2)
    log(f"Spec saved to {spec_local}", "OK")

    # ── Extract endpoints ──
    endpoints = extract_endpoints(spec)
    methods_filter = {m.strip().lower() for m in args.methods.split(",")}
    filtered_eps = [e for e in endpoints if e["method"] in methods_filter]
    log(f"Discovered {len(endpoints)} total endpoints, {len(filtered_eps)} matching methods {methods_filter}")

    if args.dry_run:
        log("DRY-RUN mode — listing endpoints:")
        for e in filtered_eps:
            url = build_url(base_url or "http://localhost", e["path"], user_params)
            print(f"  {e['method'].upper():6s} {e['path']:50s} -> {url}")
        sys.exit(0)

    # ── Step 2: Spectral Linting ──
    spectral_issues = None
    if not args.skip_spectral:
        spectral_config = args.spectral_config
        if not spectral_config:
            candidates = [root_dir / ".spectral.yml", root_dir / ".spectral.yaml"]
            for c in candidates:
                if c.is_file():
                    spectral_config = str(c)
                    break
        if spectral_config:
            spectral_output = output_dir / "spectral-results.json"
            spectral_issues = run_spectral(
                str(spec_local), spectral_config, str(spectral_output)
            )
        else:
            log("No .spectral.yml found. Skipping lint.", "WARN")

    # ── Step 3: Measure Endpoints ──
    log(f"Measuring {len(filtered_eps)} endpoints ({args.repeat} repeats each)...")
    measurements = {}
    endpoint_reports = []

    for i, ep in enumerate(filtered_eps, 1):
        url = build_url(base_url, ep["path"], user_params)
        label = f"[{i}/{len(filtered_eps)}] {ep['method'].upper()} {ep['path']}"
        log(f"  {label}")

        m = measure_endpoint(url, method=ep["method"].upper(), headers=auth_headers,
                             repeat=args.repeat, timeout=30)

        net_wh = bytes_to_wh(m["size_download"], args.network_kwh_per_gb)
        srv_wh = seconds_to_wh(m["time_total"], args.server_power_w)
        m["energy_network_wh"] = net_wh
        m["energy_server_wh"] = srv_wh
        m["energy_total_wh"] = net_wh + srv_wh

        key = f"{ep['method']}:{ep['path']}"
        measurements[key] = m

        log(f"    -> {m['http_code']}  {format_bytes(m['size_download'])}  "
            f"{m['time_total']:.3f}s  energy={m['energy_total_wh']:.6f} Wh", "OK")

        # Per-endpoint report
        ep_report = {
            "timestamp": timestamp_str,
            "service_base_url": base_url,
            "endpoint": {
                "method": ep["method"],
                "path": ep["path"],
                "url": url,
                **{k: v for k, v in m.items() if k != "response_headers"},
            },
        }
        endpoint_reports.append(ep_report)

        # Save per-endpoint file
        ep_dir = output_dir / "analysis" / "endpoints"
        ep_dir.mkdir(parents=True, exist_ok=True)
        ep_file = ep_dir / f"analysis-endpoint-{slugify(f'{ep["method"]}-{ep["path"]}')}.json"
        with open(ep_file, "w", encoding="utf-8") as f:
            json.dump(ep_report, f, indent=2)

    # ── Step 4: Green Score ──
    log("Computing Green Score...")
    green_score = analyze_green_rules(spec, endpoints, base_url, measurements, auth_headers)
    log(f"  GREEN SCORE: {green_score['total']}/{green_score['max']}  Grade: {green_score['grade']}", "OK")

    # Find the full payload key (largest GET)
    full_key = max(measurements.keys(),
                   key=lambda k: measurements[k].get("size_download", 0)) if measurements else ""

    # ── Step 5: Build Reports ──
    # Load previous report for before/after comparison
    previous_report = load_previous_report(output_dir)
    if previous_report:
        log("Previous report found — will use as baseline (before)", "OK")
    else:
        log("No previous report — first analysis: before = after", "INFO")

    # Dashboard-compatible report
    dashboard_report = build_dashboard_report(
        timestamp_str, green_score, measurements, filtered_eps,
        base_url, full_key, args.network_kwh_per_gb, args.server_power_w,
        previous_report,
    )

    # Add spectral results
    if spectral_issues is not None:
        dashboard_report["spectral"] = {
            "issues_count": len(spectral_issues),
            "errors": sum(1 for i in spectral_issues if i.get("severity") == 0),
            "warnings": sum(1 for i in spectral_issues if i.get("severity") == 1),
            "infos": sum(1 for i in spectral_issues if (i.get("severity") or 99) >= 2),
            "issues": spectral_issues[:100],
        }

    # Save reports
    report_file = output_dir / f"green-score-report-{timestamp_file}.json"
    latest_file = output_dir / "latest-report.json"

    with open(report_file, "w", encoding="utf-8") as f:
        json.dump(dashboard_report, f, indent=2)
    with open(latest_file, "w", encoding="utf-8") as f:
        json.dump(dashboard_report, f, indent=2)

    log(f"Report: {report_file}", "OK")
    log(f"Latest: {latest_file}", "OK")

    # Analysis summary
    summary = {
        "timestamp": timestamp_str,
        "service_base_url": base_url,
        "green_score": green_score,
        "totals": {
            "endpoints_discovered": len(endpoints),
            "endpoints_measured": len(measurements),
            "total_bytes": sum(m["size_download"] for m in measurements.values()),
            "total_time_s": sum(m["time_total"] for m in measurements.values()),
            "energy_total_wh": sum(m.get("energy_total_wh", 0) for m in measurements.values()),
        },
        "endpoints": [{k: v for k, v in m.items() if k != "response_headers"}
                      for m in measurements.values()],
    }
    summary_file = output_dir / "analysis" / "latest-summary.json"
    summary_file.parent.mkdir(parents=True, exist_ok=True)
    with open(summary_file, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    # ── Step 6: Generate Dashboard ──
    if not args.skip_dashboard:
        dashboard_py = script_dir / "generate-dashboard.py"
        template = root_dir / "dashboard" / "index.save.html"
        out_html = root_dir / "dashboard" / "index.html"
        if dashboard_py.is_file() and template.is_file():
            log("Generating dashboard...")
            try:
                subprocess.run([
                    sys.executable, str(dashboard_py),
                    "--report", str(latest_file),
                    "--template", str(template),
                    "--output", str(out_html),
                ], check=True, capture_output=True, text=True, timeout=30)
                log(f"Dashboard written to {out_html}", "OK")
            except Exception as e:
                log(f"Dashboard generation error: {e}", "WARN")
        else:
            log("Dashboard template or generator not found. Skipping.", "WARN")

    # ── Final Summary ──
    print()
    print("=" * 60)
    print(f"  GREEN SCORE: {green_score['total']}/{green_score['max']}   Grade: {green_score['grade']}")
    print(f"  Endpoints discovered: {len(endpoints)}")
    print(f"  Endpoints measured:   {len(measurements)}")
    print(f"  Report: {report_file}")
    print(f"  Dashboard: dashboard/index.html")
    print("=" * 60)

    # Return non-zero if below threshold
    threshold_file = root_dir / "green-score-threshold.json"
    if threshold_file.is_file():
        threshold = json.loads(threshold_file.read_text(encoding="utf-8"))
        min_score = threshold.get("minScore", 0)
        if green_score["total"] < min_score:
            log(f"FAIL: Score {green_score['total']} < threshold {min_score}", "ERR")
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

