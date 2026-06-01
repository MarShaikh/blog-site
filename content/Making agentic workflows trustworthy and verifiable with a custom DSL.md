> *This write-up is from a talk by Elicit AI @ Code w/ Claude in London on how they make their AI responses trustworthy and verifiable with a custom DSL (Domain Specific Language)*

### Trust Problem - Process?
Imagine two research systems that produce identical reports on the same question. Both cite the same papers. Both arrive at the same conclusions. Which do you trust?

The answer, perhaps counterintuitively, is: it depends entirely on what went on inside each system to produce that output.

This is the central insight driving a growing movement in agentic AI design: **mechanism matters**. How an answer is produced is as important as what it says. An AI agent that arrives at a correct answer through an undisciplined, opaque process is fundamentally less trustworthy than one that reaches the same answer through a legible, auditable sequence of steps — even if you can't immediately tell the two apart from their outputs alone. This is very important in a number of industries as one can imagine. 

This reasoning sits at the heart of the design philosophy behind Elicit's Research Agent, which offers one of the clearest examples of mechanism-first thinking in deployed agentic systems. Rather than simply searching and summarising, the Research Agent breaks a research question down into what Elicit describes as "a systematic program, then executes that program to produce reliable output where all claims are grounded in evidence." Each step in the workflow leaves a visible trail. As one review put it, there is zero "black box" effect: if the system pulls a number, you can see precisely where it came from.

Legibility matters in many applications as without it, trust in AI systems is eroded. This is not just by wrong answers, but by the inability to explain _why_ an answer was reached or _whether_ the process faithfully followed the intended approach.


### There Is No Single Right Way — Mechanism Is a Design Choice
Before exploring how to make agentic workflows verifiable, it is worth acknowledging something that is easy to overlook: there is no canonical approach. Mechanism design in AI systems is, fundamentally, a set of design choices shaped by several competing forces:

- **Domain**: A legal research pipeline has different verifiability requirements than a competitive intelligence tool or a clinical trial summariser.
- **User**: Some users want rigour and reproducibility; others need speed and breadth.
- **Task**: Exploratory research tolerates different failure modes than a systematic review intended to inform clinical practice.
- **Speed versus rigour**: More interpretable, step-by-step execution tends to be slower. Caching and approximation restore speed but introduce new questions about correctness.
- **Implementation aesthetics**: There is, inevitably, a degree of taste and brand involved in how a system expresses its reasoning.

What this means in practice is that building a trustworthy agentic system is not a problem that can be solved once. It requires deliberate, domain-specific decisions about what "trustworthy" even means in a given context.

### Data Provenance: The Non-Negotiable Foundation
Before trustworthy execution, there must be trustworthy data. Elicit's own position is that data provenance is foundational, and the broader research literature strongly supports this.

A recent survey of provenance, transparency, and traceability in large language models found that, despite the scale of modern LLM deployments, the training data lifecycle remains largely opaque. Models are generally unable to trace their outputs back to the original data sources that shaped them, and major model creators often keep data origins undisclosed. The survey proposes a taxonomy spanning data provenance, bias and uncertainty, privacy, and the operational tools needed to track these properties across a model's lifecycle.

The challenge is no less severe at inference time. When LLM agents operate in multi-step workflows, errors propagate: one agent's hallucinated output becomes another agent's input. PROV-AGENT, a recent provenance framework that extends the W3C PROV standard, directly addresses this by integrating agent interactions into end-to-end workflow provenance using the Model Context Protocol. The paper is blunt about the stakes: "assuring that agents' actions are transparent, traceable, reproducible, and reliable is critical to assess hallucination risks and mitigate their workflow impacts."

For the BRAD biomarker discovery system, the same lesson appeared in a different domain. The researchers found that commercial AI systems "obscure data provenance, lack transparency, and can generate false information, making them unfit for many research problems." Their solution was a modular agentic architecture that maintains transparent protocols throughout the research workflow.

The pattern across all of these systems is consistent: you cannot bolt provenance on at the end. It has to be a structural property of the system from the beginning.

### The Case for a Domain-Specific Language
One of the most compelling architectural choices in building verifiable agentic workflows is the use of a domain-specific language (DSL) to represent the agent's plan. This is the approach taken by Elicit's engineering team, who developed an internal language called ÆPL for expressing and executing research workflows.

#### Why Not General-Purpose Code?
The intuition behind a DSL is that the constraints you give up are the constraints that were causing the problems.

General-purpose languages like Python are Turing complete: they can express any computation. That power is also their weakness in agentic settings. A Turing-complete language can loop indefinitely, mutate shared state unpredictably, and produce side effects that are difficult to reason about. When an LLM generates arbitrary Python, you cannot easily verify that the generated code does only what was intended.

A Turing-incomplete, purely functional, reactive DSL, which is how ÆLP is described, gives you something different: a restricted computational model where the set of expressible behaviours is bounded. The interpreter can walk the entire program at once, verify it, and execute it with confidence. This is directly analogous to what the broader formal methods literature describes for agent workflow graphs: static verification is only tractable when the space of possible behaviours is constrained.

As a 2026 analysis of DSLs in AI agent architectures put it: "the DSL captures decisions. The compiler enforces constraints and produces deterministic output. AI does the creative authoring. Humans do the reviewing and approving."

#### The Architecture: Curator, Gateway, and Content-Addressable Store
The full system spans two distinct tiers, connected by an event-driven data model that is itself a key source of trustworthiness.

![[elicit-agentic-workflow.png]]

At the top, a **UI** layer emits user events — queries, interactions, updates — but rather than acting on these directly, it feeds them into an **Event Log**. This log is the canonical data structure for the system: a durable, append-only record of everything the user has done. The Event Log feeds a **Python Service**, which brokers messages and is responsible for interpreting ÆPL programs. Critically, because all state flows through the Event Log, the entire system is replayable. If you have the log, you can reconstruct exactly what the system was doing at any point in time.

The Python Service dispatches into a **Sandbox**, a self-contained execution environment housing three components arranged in a deliberate layering:
- The **Wrapper** sits at the top of the sandbox. It acts as an event reducer and harness abstracter: it receives the structured events from the Python Service and shields the layers below from needing to know anything about which LLM harness or execution environment is underneath. This abstraction layer is what makes it possible to swap model providers or execution backends without touching the core logic.
- Below the Wrapper sits the **Curator**, the component that writes ÆPL. This is the LLM-facing piece: it receives the reduced, canonicalised representation of the user's intent and translates it into a formal, executable ÆPL program. The Curator does not execute anything; it only authors.
- At the base of the sandbox is the **Gateway**, which mediates every interaction with the underlying model, in this case, Claude. The Gateway's role is to keep API keys safe and to ensure that all model calls pass through a single, controlled, auditable point. 

The sandbox boundary itself is the key trust boundary in the architecture.
#### The Content-Addressable Store
Completing the picture is a **content-addressable store** that sits alongside the execution loop. Because the store uses hashing to represent expressions, identical sub-computations can be detected and reused across iterations. The entire ÆPL program is redrafted from scratch on each loop, but because previously computed results are cached by content address, this redrafting is cheap. You get the interpretability benefits of reinterpreting the whole program (drift detection, confidence in what was actually executed) without paying the full computational cost each time.

This design mirrors an emerging pattern in production agentic systems. Agentic Plan Caching (APC), presented at NeurIPS 2025, demonstrates that reusing structured plan templates across similar tasks can reduce costs by 50% and latency by 27% while maintaining performance, and that the key to doing this safely is ensuring the caching mechanism is sensitive to the contextual differences between runs, not just the superficial similarity of queries.

#### The Plan Is Not a Representation of the Plan
One of the more philosophically interesting aspects of a DSL-based approach is what it means for the relationship between planning and execution.

In many agentic frameworks, a planning phase produces a high-level description of what the agent intends to do, and a separate execution phase attempts to carry it out. The plan and the execution are distinct artefacts, which means there is always a gap: the execution might not faithfully follow the plan.

With ÆPL, this distinction collapses. The DSL program _is_ the plan, not a natural-language summary of it, not a sequence of prompts that gesture toward it, but a formal, executable specification. When the interpreter runs the program, it is not approximating the plan; it is running it. This eliminates an entire class of drift problems.


#### The Drift Problem and Process Fidelity
One of the most practically damaging failure modes in iterative research workflows is **drift**: the tendency for a system to gradually deviate from its initial research question over the course of a long computation. Each step is locally reasonable, but the cumulative effect is a final output that has wandered far from what the user originally wanted.

Drift is particularly insidious because it is hard to detect after the fact. If you only examine the final output, the deviation from the original intent may not be obvious. The only reliable way to detect drift is to preserve and examine the full sequence of intermediate steps.

This is precisely why process legibility matters as much as output quality. When each step in a research workflow is encoded in a formal language and logged against a content-addressable store, every intermediate state is available for inspection. You can compare what was done at step 7 against the original program specification and ask: is this still what we intended?

The counterpart to drift is **hallucination propagation** in multi-agent systems. When agents operate in sequence, errors compound in ways that are difficult to detect from outputs alone. TrustBench, a 2026 framework for real-time trust verification, addresses this by intervening at the critical decision point — after an agent formulates an action but before it is executed, and applying domain-specific verification rules. In their experiments, domain-specific plugins outperformed generic verification, achieving 35% greater harm reduction, with sub-200ms latency making the approach practical for real-time use.


#### The Harder Parts: Evaluation, Not Language Design
Something worth foregrounding: the DSL itself was not the hard part. By the account of those who built ÆPL, a small fraction of the total development effort went into the language design and interpreter. The genuinely time-consuming work was everything else, particularly evaluation.

Building confidence in a system that generates and interprets its own programs requires a rigorous evaluation harness. You need to know whether the code the LLM generates is actually correct, whether the interpreter faithfully executes it, and whether the outputs that emerge are trustworthy in the sense that matters to the user. None of these questions can be answered by inspection alone; they require systematic testing across a distribution of real tasks.

AgentProof, a 2026 paper on static verification of agent workflow graphs, makes an analogous point from the formal methods side: general-purpose model checkers exist, but the "prohibitive overhead" of manually translating agent workflows into dedicated modelling languages has limited their adoption. The benefit of a purpose-built DSL is that the verification problem and the language can be co-designed, but that co-design still requires significant investment.


### Not for Everyone

A DSL-based agentic architecture is not the right choice for every team or every application. The development investment is substantial. The opinionated constraints of a Turing-incomplete language mean that some workflows that would be natural to express in Python become awkward or impossible to express in the DSL. And the tooling ecosystem around custom languages is, by definition, smaller than the ecosystem around established general-purpose languages.

The right framing is probably this: a DSL becomes worth the investment when the cost of opacity and drift in your workflows exceeds the cost of building and maintaining a restricted execution environment. For research workflows where provenance, reproducibility, and trust are core product requirements; systematic reviews, competitive intelligence, regulatory document analysis, that threshold is likely to be crossed. For simpler, lower-stakes automation, it probably is not.

The broader pattern, though, is becoming harder to ignore: as agentic systems are deployed in higher-stakes domains, the question of _how_ they produce their outputs is becoming as important as _what_ they produce. 


### Conclusion
The question "which of these two systems do you trust?" does not have an answer that can be read off from the outputs alone. Trust in agentic AI is a property of process, of whether the steps taken to produce an answer are legible, auditable, and faithful to the original intent.

Building systems with these properties is difficult. It requires deliberate choices about language and execution model, serious investment in evaluation infrastructure, and a willingness to accept the constraints that come with a restricted computational model. Data provenance must be built in from the start, not appended as an afterthought.

But the prize is significant: a system whose outputs you can trust not just because they look right, but because you can see, step by step, how they were produced.

## References and Further Reading

- Elicit. (2025). _Introducing Research Agent Workflows_. elicit.com/blog
- Hohensinner, R. et al. (2026). _Tracing the Data Trail: A Survey of Data Provenance, Transparency and Traceability in LLMs_. arXiv:2601.14311
- Oak Ridge National Laboratory / arXiv. (2025). _LLM Agents for Interactive Workflow Provenance: Reference Architecture and Evaluation Methodology_. arXiv:2509.13978
- PROV-AGENT. (2025). _Unified Provenance for Tracking AI Agent Interactions in Agentic Workflows_. arXiv:2508.02866
- TrustBench. (2026). _Real-Time Trust Verification for Safe Agentic Actions_. arXiv:2603.09157
- AgentProof. (2026). _Static Verification of Agent Workflow Graphs_. arXiv:2603.20356
- Agentic Plan Caching (APC). (2025). _Test-Time Memory for Fast and Cost-Efficient LLM Agents_. NeurIPS 2025 / arXiv:2506.14852
- TrustTrack. (2026). _From Cloud-Native to Trust-Native: A Protocol for Verifiable Multi-Agent Systems_. arXiv:2507.22077
- BRAD. (2025). _Automatic Biomarker Discovery and Enrichment with BRAD_. PMC12064167
- Endo, T. (2026). _Domain-Specific Languages: The Deterministic Backbone of AI Agents_. Medium.