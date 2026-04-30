# OpenAPI Infrastructure Extensions

> **Why?** The Green Score Analyzer discovers an API only via its OpenAPI/Swagger
> spec. Infrastructure choices (Kubernetes, KEDA, scale-to-zero, event-driven,
> async API, GraalVM native, carbon-aware regions…) have a **major energy
> impact** but are invisible to a pure OpenAPI reader. By declaring them as
> standard `x-*` extensions in the spec, the analyzer can **see** them,
> **score** them, and **report** them — without requiring access to your
> Kubernetes manifests or cloud provider.

## Three levels of declaration

| Level | Extension key | Use for |
|---|---|---|
| Root spec | `x-infrastructure` | Platform-wide declarations (k8s, autoscaling, runtime, sustainability) |
| `servers[*]` | `x-server-compression`, `x-server-etag-support`, `x-server-range-support` | Server capabilities (already used) |
| Operation | `x-async-pattern`, `x-event-driven`, `x-scaling-profile` | Per-endpoint async / event / scaling hints |

## Root schema — `x-infrastructure`

```yaml
x-infrastructure:
  platform:
    type: kubernetes              # kubernetes | vm | serverless | container | bare-metal
    provider: aks                 # aks | eks | gke | openshift | k3s | self-managed
    region: francecentral
    carbonAware: true             # carbon-aware scheduler enabled?

  autoscaling:
    enabled: true
    type: keda                    # hpa | keda | knative | vpa | cluster-autoscaler | none
    minReplicas: 0                # 0 = scale-to-zero (KEDA / Knative)
    maxReplicas: 10
    scaleToZero: true
    cooldownSeconds: 300
    triggers:                     # KEDA-style triggers (free-form list)
      - { type: cpu,        target: 70 }
      - { type: prometheus, query: http_requests_per_second, target: 100 }
      - { type: kafka,      topic: book.events, lag: 50 }

  architecture:
    style: rest                   # rest | graphql | grpc | hybrid
    paradigm: reactive            # synchronous | asynchronous | reactive
    eventDriven:
      enabled: true
      brokers: [{ type: kafka, topics: [book.changes] }]
      patterns: [pub-sub, cqrs, event-sourcing]
    asyncApi:
      enabled: true
      specUrl: /asyncapi.yaml

  runtime:
    container: true
    jvm: hotspot                  # hotspot | graalvm | graalvm-native
    image: eclipse-temurin:21-jre-alpine

  sustainability:
    idleShutdown: true
    pue: 1.12
    greenEnergy: true
```

## Per-operation extensions

Use Swagger's `@Operation(extensions = …)` (Java) or directly in YAML/JSON:

```java
@Operation(summary = "List books changed since …",
  extensions = {
    @Extension(name = "x-async-pattern", properties = {
      @ExtensionProperty(name = "type",        value = "long-polling"),
      @ExtensionProperty(name = "alternative", value = "sse|webhook")
    }),
    @Extension(name = "x-event-driven", properties = {
      @ExtensionProperty(name = "consumes", value = "book.changes"),
      @ExtensionProperty(name = "broker",   value = "kafka")
    }),
    @Extension(name = "x-scaling-profile", properties = {
      @ExtensionProperty(name = "hot",         value = "false"),
      @ExtensionProperty(name = "scaleToZero", value = "true")
    })
  })
```

## Bonus signals awarded by the analyzer

| ID | Signal | +pts | Trigger |
|---|---|---|---|
| `IN01` | Kubernetes + autoscaling declared        | +5 | `platform.type=kubernetes` AND `autoscaling.enabled=true` |
| `IN02` | Scale-to-zero (KEDA / Knative)          | +5 | `autoscaling.scaleToZero=true` OR `minReplicas=0` |
| `AR03` | Event-driven / Async API                | +5 | `architecture.eventDriven.enabled=true` OR any op with `x-async-pattern` |
| `RT01` | Efficient runtime (GraalVM native)      | +3 | `runtime.jvm` ∈ {`graalvm-native`, `graalvm`, `native-image`} |
| `SU01` | Carbon-aware / green region             | +2 | `sustainability.greenEnergy=true` OR `platform.carbonAware=true` |
|  | **Max bonus** | **+20** | Reported as `infrastructure.bonus_total` (separate from /100 base) |

## Where this is implemented

| File | Role |
|---|---|
| `green-api-optimized/src/main/java/com/example/optimized/config/OpenApiInfraConfig.java` | Spring `@Configuration` injecting `x-infrastructure` into the OpenAPI bean |
| `green-api-optimized/src/main/java/com/example/optimized/api/BookReactiveController.java` | Per-operation `@Extension` annotations on `/changes` and `POST /{id}/summary` |
| `greenanalyzer/scripts/green-api-auto-discover.py` → `extract_infrastructure(...)` | Parser + bonus-signals computation |
| `reports/latest-report.json` → `report.infrastructure` | Output block consumed by the dashboard |

## Verification

```bash
# 1. Start the optimized API
mvn -pl green-api-optimized spring-boot:run

# 2. Inspect the spec — the x-infrastructure block must be visible
curl -s http://localhost:8081/v3/api-docs | jq '.["x-infrastructure"]'

# 3. Run the analyzer — look for the "INFRA" log line + report.infrastructure
python3 greenanalyzer/scripts/green-api-auto-discover.py --target http://localhost:8081
jq '.report.infrastructure.bonus_signals' greenanalyzer/reports/latest-report.json
```

