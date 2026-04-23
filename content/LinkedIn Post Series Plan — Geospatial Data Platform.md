Focus: STAC API + Microsoft Planetary Computer + Multi-agent LLM infrastructure.

Source notes: `Notes/Geospatial Data Platform/`

---

[[Two characters broke my STAC API]]
**Hook:** A working deployment that silently fails — and the weirdly specific JSON serialization bug that caused it.

**Covers:**
- `datetime: {}` vs `datetime: null`
- The 400-bad-request rabbit hole with no useful logs
- Why `jsonlite` made the debugging harder
- What I learned about reading STAC error responses

**Why this post:** Most hands-on, most technical, best for engineers scrolling LinkedIn who've hit similar walls.

---

[[Indexing data I don't own]]
**Hook:** Two weeks of fighting with NASA CMR links and HDF4 files — then realizing Microsoft Planetary Computer already had what I needed, signed and ready.

**Covers:**
- The original plan (ingest CHIRPS + MODIS into my own Azure blob store)
- Why MPC changes the shape of the problem
- The STAC-as-index insight (you don't have to own the bytes to own the catalog)
- The uncomfortable design question underneath it

**Why this post:** The architectural pivot. This is where the project got interesting.

---

## Post 3 — "Four agents is enough: putting a chat interface on a STAC catalog"

**Hook:** Earth Copilot uses 13 specialized agents. I'm building with 4. Here's why fewer worked better as a starting point.

**Covers:**
- The sequential pipeline (parser → geocoder → STAC query → synthesizer)
- Why Microsoft Agent Framework over Semantic Kernel or LangChain
- Function tools vs. prompt-engineering
- What "give me rainfall in Lagos last month" actually has to become before it hits the API

**Why this post:** Multi-agent LLM infra grounded in a real, constrained domain — not a generic "how to build an agent" post.

---

## Post 4 — "Why I skipped MCP for the MVP — and what it taught me about premature abstraction"

**Hook:** Everyone's plugging MCP into everything. I spent a week seriously considering it, then chose not to. Here's the line I used.

**Covers:**
- What MCP actually buys you (reusable tools, Claude Desktop integration)
- What it costs (protocol layer, less UX control)
- Why "tools-focused" is wrong for a domain chat app with maps and code execution
- The hybrid path (FastAPI now, wrap in MCP later if demand appears)

**Why this post:** Opinionated and forward-looking. The kind of post that sparks discussion, which is what LinkedIn actually rewards.

---

## Order recommendation

- **Post 1** is the safest opener (concrete, relatable, low stakes)
- **Post 3** or **Post 4** would get more engagement for something people are actively talking about