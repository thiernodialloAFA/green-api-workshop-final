# ─────────────────────────────────────────────────────────────
#  Green API Workshop — Makefile
#  Devoxx France 2026 — Green Architecture
# ─────────────────────────────────────────────────────────────

.DEFAULT_GOAL := help

TARGET_URL   ?= http://localhost:8081
SWAGGER_URL  ?=
BEARER_TOKEN ?=
REPEAT       ?= 3

SCRIPTS_DIR  := scripts
REPORTS_DIR  := reports
DASHBOARD    := dashboard/index.html
TEMPLATE     := dashboard/index.save.html

# ── Help ───────────────────────────────────────────────────
.PHONY: help
help:  ## Show this help
	@echo ""
	@echo "  Green API Workshop — Available targets:"
	@echo "  ────────────────────────────────────────"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ── Auto-Discover & Analyze ────────────────────────────────
.PHONY: analyze
analyze:  ## Auto-discover + measure + green score + dashboard
	python3 $(SCRIPTS_DIR)/green-api-auto-discover.py \
		--target $(TARGET_URL) \
		$(if $(SWAGGER_URL),--swagger $(SWAGGER_URL),) \
		$(if $(BEARER_TOKEN),--bearer $(BEARER_TOKEN),) \
		--repeat $(REPEAT)

.PHONY: analyze-dry
analyze-dry:  ## Dry-run: list discovered endpoints without calling them
	python3 $(SCRIPTS_DIR)/green-api-auto-discover.py \
		--target $(TARGET_URL) \
		$(if $(SWAGGER_URL),--swagger $(SWAGGER_URL),) \
		--dry-run

# ── Legacy analyzer (hardcoded endpoints) ──────────────────
.PHONY: analyze-legacy
analyze-legacy:  ## Run the original green-score-analyzer.sh
	bash $(SCRIPTS_DIR)/green-score-analyzer.sh

# ── Dashboard only ─────────────────────────────────────────
.PHONY: dashboard
dashboard:  ## Regenerate dashboard from latest report
	python3 $(SCRIPTS_DIR)/generate-dashboard.py \
		--report $(REPORTS_DIR)/latest-report.json \
		--template $(TEMPLATE) \
		--output $(DASHBOARD)

# ── Détection automatique container runtime (docker ou podman) ──
CONTAINER_RT := $(shell command -v podman >/dev/null 2>&1 && echo podman || echo docker)
CONTAINER_COMPOSE := $(CONTAINER_RT) compose

# ── Container ──────────────────────────────────────────────
.PHONY: up
up:  ## Start all services (baseline + optimized + dashboard)
	$(CONTAINER_COMPOSE) up -d baseline optimized dashboard

.PHONY: up-analyze
up-analyze:  ## Start services + run analyzer
	$(CONTAINER_COMPOSE) up -d baseline optimized dashboard
	$(CONTAINER_COMPOSE) run --rm analyzer

.PHONY: up-auto
up-auto:  ## Start services + run auto-discover
	$(CONTAINER_COMPOSE) up -d optimized
	$(CONTAINER_COMPOSE) --profile auto-discover run --rm auto-discover

.PHONY: down
down:  ## Stop all services
	$(CONTAINER_COMPOSE) down

# ── Spectral lint only ─────────────────────────────────────
.PHONY: lint
lint:  ## Run Spectral lint on the discovered spec
	@if [ -f $(REPORTS_DIR)/discovered-openapi.json ]; then \
		npx @stoplight/spectral-cli lint $(REPORTS_DIR)/discovered-openapi.json \
			--ruleset .spectral.yml; \
	else \
		echo "No spec found. Run 'make analyze' first."; \
	fi

# ── CI gate ────────────────────────────────────────────────
.PHONY: ci-gate
ci-gate: analyze  ## Run analysis + fail if below threshold
	@echo "CI gate passed (threshold checked by analyzer)"

