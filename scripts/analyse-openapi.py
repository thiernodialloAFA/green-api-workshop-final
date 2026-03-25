#!/usr/bin/env python3
"""Minimal OpenAPI/Swagger analyzer with energy estimate (stdlib only)."""

import argparse
import json
import os
import re
import sys
import time
import urllib.request
from datetime import datetime

try:
    import yaml  # type: ignore
except Exception:
    yaml = None


def parse_spec_text(text: str, source_label: str):
    try:
        return json.loads(text)
    except Exception:
        if yaml is not None:
            try:
                return yaml.safe_load(text)
            except Exception:
                pass
        raise ValueError(f"Swagger JSON/YAML invalide ({source_label}).")


def load_spec(source: str):
    if source.startswith("http://") or source.startswith("https://"):
        with urllib.request.urlopen(source) as resp:
            return parse_spec_text(resp.read().decode("utf-8"), source)
    with open(source, "r", encoding="utf-8") as handle:
        return parse_spec_text(handle.read(), source)


def resolve_base_url(spec, explicit_base):
    if explicit_base:
        return explicit_base.rstrip("/")
    servers = spec.get("servers") or []
    if servers:
        return servers[0].get("url", "").rstrip("/")
    if spec.get("swagger") == "2.0":
        scheme = (spec.get("schemes") or ["http"])[0]
        host = spec.get("host", "localhost")
        base_path = spec.get("basePath", "")
        return f"{scheme}://{host}{base_path}".rstrip("/")
    return ""


def extract_endpoints(spec, methods):
    endpoints = []
    for path, ops in (spec.get("paths") or {}).items():
        for method, op in ops.items():
            if method.lower() not in methods:
                continue
            endpoints.append({
                "path": path,
                "method": method.lower(),
                "operationId": op.get("operationId") or f"{method}_{path}",
                "parameters": op.get("parameters", [])
            })
    return endpoints


def apply_params(path, params):
    def replacer(match):
        key = match.group(1)
        return str(params.get(key, "1"))
    return re.sub(r"\{([^}]+)\}", replacer, path)


def append_query(url, params, parameters_def):
    required = [p.get("name") for p in parameters_def if p.get("in") == "query" and p.get("required")]
    query = {k: v for k, v in params.items() if v is not None}
    for name in required:
        query.setdefault(name, "1")
    if not query:
        return url
    parts = [f"{k}={v}" for k, v in query.items()]
    return url + ("&" if "?" in url else "?") + "&".join(parts)


def build_url(base, path, params, parameters_def):
    filled = apply_params(path, params)
    base = base.rstrip("/")
    url = f"{base}{filled if filled.startswith('/') else '/' + filled}"
    return append_query(url, params, parameters_def)


def bytes_to_wh(size_bytes, network_kwh_per_gb):
    gb = size_bytes / (1024 * 1024 * 1024)
    return gb * network_kwh_per_gb * 1000


def ms_to_wh(ms, power_w):
    return (ms / 1000) * (power_w / 3600)


def slugify(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def load_previous_summary(path):
    if not os.path.exists(path):
        return None
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def main():
    parser = argparse.ArgumentParser(description="Analyse un swagger et mesure les endpoints.")
    parser.add_argument("--swagger", required=True, help="URL ou chemin vers un OpenAPI JSON")
    parser.add_argument("--base-url", default="", help="Endpoint base (optionnel)")
    parser.add_argument("--output-dir", default="reports/analysis/endpoints", help="Dossier par endpoint")
    parser.add_argument("--summary-output", default="reports/analysis/latest-summary.json", help="Fichier resume")
    parser.add_argument("--method", action="append", default=["get"], help="Methode a analyser (ex: --method get)")
    parser.add_argument("--param", action="append", default=[], help="Parametre key=value")
    parser.add_argument("--bearer", default="", help="Bearer token (optionnel)")
    parser.add_argument("--network-kwh-per-gb", type=float, default=0.06, help="Intensite reseau (kWh/GB)")
    parser.add_argument("--server-power-w", type=float, default=25.0, help="Puissance serveur (W)")
    parser.add_argument("--repeat", type=int, default=1, help="Repetitions par endpoint")
    parser.add_argument("--dry-run", action="store_true", help="Liste les endpoints sans appel")
    args = parser.parse_args()

    params = {}
    for item in args.param:
        if "=" not in item:
            print(f"Parametre invalide: {item}", file=sys.stderr)
            sys.exit(2)
        key, value = item.split("=", 1)
        params[key] = value

    try:
        spec = load_spec(args.swagger)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        if yaml is None and args.swagger.lower().endswith((".yaml", ".yml")):
            print("Installez pyyaml pour le support YAML.", file=sys.stderr)
        sys.exit(2)
    base_url = resolve_base_url(spec, args.base_url)
    if not base_url:
        print("Endpoint base introuvable. Fournissez --base-url.", file=sys.stderr)
        sys.exit(2)

    methods = [m.lower() for m in args.method]
    endpoints = extract_endpoints(spec, methods)
    if not endpoints:
        print("Aucun endpoint a analyser.")
        return 0

    if args.dry_run:
        for ep in endpoints:
            url = build_url(base_url, ep["path"], params, ep["parameters"])
            print(f"{ep['method'].upper()} {ep['path']} -> {url}")
        return 0

    previous = load_previous_summary(args.summary_output)
    previous_map = {}
    if previous and previous.get("endpoints"):
        for ep in previous["endpoints"]:
            previous_map[f"{ep['method']}:{ep['path']}"] = ep

    os.makedirs(args.output_dir, exist_ok=True)

    headers = {}
    if args.bearer:
        headers["Authorization"] = f"Bearer {args.bearer}"

    results = []
    for ep in endpoints:
        url = build_url(base_url, ep["path"], params, ep["parameters"])
        total_ms = 0.0
        total_bytes = 0
        status = 0

        for _ in range(max(1, args.repeat)):
            start = time.perf_counter()
            try:
                request = urllib.request.Request(url, method=ep["method"].upper(), headers=headers)
                with urllib.request.urlopen(request) as resp:
                    data = resp.read()
                    status = getattr(resp, "status", 200)
            except Exception as exc:
                print(f"Erreur {url}: {exc}", file=sys.stderr)
                data = b""
                status = 0
            total_ms += (time.perf_counter() - start) * 1000
            total_bytes += len(data)

        avg_ms = total_ms / max(1, args.repeat)
        avg_bytes = int(total_bytes / max(1, args.repeat))
        network_wh = bytes_to_wh(avg_bytes, args.network_kwh_per_gb)
        server_wh = ms_to_wh(avg_ms, args.server_power_w)
        energy_wh = network_wh + server_wh

        current = {
            "method": ep["method"],
            "path": ep["path"],
            "url": url,
            "status": status,
            "time_ms": avg_ms,
            "size_bytes": avg_bytes,
            "energy_wh": energy_wh,
            "energy_network_wh": network_wh,
            "energy_server_wh": server_wh,
        }

        prev = previous_map.get(f"{ep['method']}:{ep['path']}")
        if prev:
            current["delta"] = {
                "time_ms": avg_ms - prev.get("time_ms", 0),
                "size_bytes": avg_bytes - prev.get("size_bytes", 0),
                "energy_wh": energy_wh - prev.get("energy_wh", 0),
            }
        else:
            current["delta"] = {"time_ms": 0, "size_bytes": 0, "energy_wh": 0}

        results.append(current)

        slug = slugify(f"{ep['method']}-{ep['path']}")
        endpoint_path = os.path.join(args.output_dir, f"analysis-endpoint-{slug}.json")
        with open(endpoint_path, "w", encoding="utf-8") as handle:
            json.dump({
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "service_base_url": base_url,
                "swagger_source": args.swagger,
                "constants": {
                    "network_kwh_per_gb": args.network_kwh_per_gb,
                    "server_power_w": args.server_power_w,
                    "repeat": args.repeat
                },
                "endpoint": current
            }, handle, indent=2)

    totals = {
        "total_time_ms": sum(e["time_ms"] for e in results),
        "total_bytes": sum(e["size_bytes"] for e in results),
        "energy_total_wh": sum(e["energy_wh"] for e in results),
        "energy_network_wh": sum(e["energy_network_wh"] for e in results),
        "energy_server_wh": sum(e["energy_server_wh"] for e in results),
        "delta_energy_wh": sum(e.get("delta", {}).get("energy_wh", 0) for e in results)
    }

    summary = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "service_base_url": base_url,
        "swagger_source": args.swagger,
        "constants": {
            "network_kwh_per_gb": args.network_kwh_per_gb,
            "server_power_w": args.server_power_w,
            "repeat": args.repeat
        },
        "totals": totals,
        "endpoints": results
    }

    os.makedirs(os.path.dirname(args.summary_output), exist_ok=True)
    with open(args.summary_output, "w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2)

    print(f"Resume ecrit: {args.summary_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

