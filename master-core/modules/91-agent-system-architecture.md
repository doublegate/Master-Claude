# 91 — Agent & Assistant System Architecture

Project-agnostic rules for building systems where an LLM is a component, not the product:
assistants, agents, orchestrators, MCP servers, and memory services. Applies when you ship
the harness; keep detailed rationale in the project's accompanying architecture documentation.

## Layering

- Split responsibilities into five layers: **LLM, Memory, Tooling, Routing, Observability**.
- Give each layer one owner and one interface; do not let a prompt string carry routing,
  retrieval, and tool policy at once.
- Define the system's contract above the model call: request = intent + identity + session +
  attachments + policy; response = answer + actions + citations + state changes + trace id.
- Start with one orchestrator, one durable memory path, one trace per request, one tool policy.
  Add multi-agent topology only after single-agent failure cases are explainable without guessing.

## Tool boundary

- Treat tool use as a contract: the model emits a structured request, the runtime executes, the
  result returns to the context. The model never executes anything itself.
- Define every tool with a strict schema and validate arguments at the boundary. A sloppy tool
  boundary makes the whole assistant sloppy.
- Make tool handlers idempotent and give mutating tools an idempotency key; retries are normal.
- Gate side-effecting tools behind an explicit approval step, not behind prompt wording.
- Expose external capabilities through a standard protocol (MCP) rather than a bespoke connector
  per system; keep the agent-to-integration seam replaceable.

## Memory

- Separate the tiers explicitly: **working** (current task scratch), **session** (conversation),
  **durable** (survives sessions). Do not collapse them into "longer context".
- Define read-after-write visibility per tier and write it down. "Memory updated" and "memory
  visible to the current answer" are different truths; a frozen session snapshot preserves
  prefix-cache performance but hides writes made during the turn.
- Promote to durable memory through review, not automatically. An unreviewed write is how a
  wrong fact becomes permanent and reaches every future session.
- Retrieval is not a longer prompt: budget context, rank, and place decisive facts early.
  Recall degrades in the middle of a long context regardless of the window size.
- Evaluate retrieval as its own component with its own metrics, separately from generation.

## Routing

- Route on more than model choice: provider path, tenant, budget, latency class, and fallback.
- Give the router explicit policies (weighted, least-busy, latency-based, cost-based) and
  bounded failover; an unbounded retry chain is an outage amplifier.
- Use auxiliary model slots for chores — summarization, compression, classification, routing —
  and reserve the primary model for the reasoning the product is actually selling.
- Keep sessions sticky where behavior consistency matters; route per-request only where it does not.

## Observability

- Emit one trace per request, one span per model call, one event per tool execution. A system
  without these is not observable, whatever its dashboards show.
- Record for every request: which context was assembled, which tool ran, which model answered,
  which memory was read or written. Every production disagreement reduces to one of these.
- Track cost and token usage per route and per tenant, not only in aggregate.
- Gate changes to prompts, routes, retrieval, and memory policy behind regression evals. Prompt
  changes are code changes and deserve the same regression-evaluation gate.

## Failure modes → mitigation

| Symptom | Usual cause | Mitigation |
|---|---|---|
| Confident but off-target answer | irrelevant or badly ordered context | budget context, rerank, put key facts early |
| Right tone, wrong facts | bad chunking, stale index, weak filters | evaluate retrieval separately; metadata filters, hybrid search |
| Wrong or duplicated action | loose schemas, retries without idempotency | tight schemas, idempotency keys, approval gates |
| Behavior varies per request | cost/latency routing without quality control | sticky sessions, per-route evals |
| Stale or poisoned recall | over-eager writes, weak review, cross-session leakage | separate tiers, review promotions |
| Cannot explain an incident | missing traces or coarse spans | root span plus subspans for retrieval, model, tool |
| Plausible unsupported claims | weak grounding, no validation pass | reference-doc validation, self-consistency checks, eval gates |

## Harness safety (when your system runs agents)

- Enforce policy in the runtime, not in the system prompt. Instructions shape what an agent
  tries; only the runtime decides what it may do.
- Run untrusted-input parsing and tool execution with the narrowest privilege that works.
- Log every privileged or destructive action with who, what, when, and scope before it runs.
- Assume any content a sub-component reads may carry injected instructions — including diffs,
  retrieved documents, and tool output. Never let retrieved text change permission decisions.

## Out of scope here (keep in project stub)

- Named vendors, model IDs, pricing, and context-window sizes.
- Concrete vector store, gateway, proxy, and tracing-backend choices.
- Per-project latency budgets, token ceilings, and route tables.
- The specific schema technology for tool contracts.

> Language commands: see master-core/lang/<lang>.md
