# 91 — Agent & Assistant System Architecture

## Why it matters

A production assistant is not "an LLM with a prompt". It is a runtime that turns intent into a
response or an action by combining a model interface, context assembly, tool execution, state
management, and telemetry. Teams that skip that framing ship a demo that works and a product
that cannot be debugged: when an answer is wrong there is no way to tell whether the context was
bad, the retrieval was stale, the wrong model answered, the tool misfired, or memory returned
something written three sessions ago.

The failure is rarely the base model. It is the surrounding system lying to the model, starving
it of the right context, letting tool contracts drift, or making the whole path unobservable.
The patterns below generalize across any assistant, agent, orchestrator, or MCP service,
independent of provider.

## Patterns

**Split the system into five layers with one owner each.**
LLM (reason, generate, emit structured calls), Memory (session state, durable notes, searchable
knowledge), Tooling (read data, take action), Routing (choose model, backend, policy, tenant),
Observability (explain what happened). The split matters because every production disagreement
reduces to a question about exactly one layer, and a layer with no owner is a layer with no
answer. Collapsing them into a large prompt string means every incident becomes archaeology.

**Start boring, then add topology.**
One orchestrator, one durable memory path, one trace per request, one explicit tool-execution
policy. Multi-agent graphs are useful, but only once you can explain your single-agent failure
cases without guessing. Distributed topology multiplies the debugging surface before it
multiplies capability.

**Treat tool use as a contract boundary, not magic.**
Every provider implements the same shape: the model emits a structured request, some runtime
executes it, the result flows back into the conversation. The model never executes anything on
its own. That makes the tool schema an API contract with an unusually unreliable caller — so it
gets strict validation, idempotency for anything mutating, and an approval gate for anything
destructive. Retries are routine in this architecture; a non-idempotent tool turns a retry into
a duplicate charge.

**Standardize the integration seam.**
Without a protocol, an agent accumulates one bespoke connector per system and the integration
surface becomes the product. With a standard client-server protocol (MCP), the agent holds one
client and capabilities are discovered at runtime, which keeps the agent and its integrations
independently replaceable.

**Design memory as tiers with explicit visibility rules.**
Working memory (task scratch), session memory (the conversation), and durable memory (survives
sessions) have different lifetimes, different review requirements, and different consistency
guarantees. The subtle part is visibility: "memory updated" and "memory visible to the current
answer" are usually different truths. Systems that freeze memory into a session-start snapshot
do it deliberately, to preserve prefix-cache performance — the cost is that writes during a turn
are not visible until the next one. Write the rule down per tier, or you will ship a bug that
reproduces only on the second message.

**Promote to durable memory through review.**
Automatic promotion is how a wrong fact becomes permanent. A background consolidation process
that prunes, merges, and resolves conflicts has broad write access to everything the system
knows; a bad merge silently rewrites the premises of every future session. Gate promotion on
review, and keep specific hard-won facts from being flattened into a general one.

**Retrieval is not a longer prompt.**
Recall degrades for material in the middle of a long context, regardless of how large the window
is. Budget context, rank it, and place decisive facts early. Evaluate retrieval as its own
component with its own metrics: an assistant whose tone is right and whose facts are wrong
almost always has a retrieval problem being measured as a generation problem.

**Route an execution lane, not just a model.**
"Which model?" is never the only question — there is also which provider path, which tenant,
which budget, which latency class, and which fallback. Bound the failover: an unbounded retry
chain converts a slow dependency into an outage. And use auxiliary slots for chores.
Summarization, compression, classification, and routing do not need the model the product is
selling; spending premium tokens on them is pure margin loss.

**Emit a trace per request, a span per model call, an event per tool execution.**
This is the difference between an architecture and folklore. The questions that actually get
asked in an incident are: what context was visible, which tool executed, which model answered,
which memory was read or written, and where did the time go. If the telemetry cannot answer
those, no amount of dashboard fixes it.

**Gate prompt, route, retrieval, and memory-policy changes behind evals.**
These are code changes with unusually high blast radius and unusually low review visibility — a
one-line prompt edit can change every answer the system gives. Regression evals are the only
mechanism that makes their effect legible before users find it.

**Enforce agent policy in the runtime, not the system prompt.**
Instructions shape what an agent tries to do; only the runtime decides what it may actually do.
This is the same lesson the harness-safety literature reaches from the other direction: as
agents gain skills, memory, subagents, and external services, the interesting attack surface
moves from the model's output to the system's configuration. Assume any content a component
reads — retrieved documents, diffs, tool output — may carry injected instructions, and never let
retrieved text influence a permission decision.

## Applies to

Any project where an LLM is a component of a larger system rather than the deliverable itself:
assistants, agent orchestrators, MCP servers, memory and knowledge-graph services, and
multi-model routing layers.
