# Greffier

**An anchored legal research engine. It keeps the record; it never judges.**

Greffier answers a question of French law with items **all tied to an
authentic text**: a code article or a court decision, identified by its
official identifier (`LEGIARTI…`, `ECLI…`) and its version in force. It never
asks a language model to cite a text, because a model that cites invents,
and its reader cannot tell.

It is meant for those who need *the rule that applies to an everyday
situation* without being lawyers — conciliators and mediators, legal aid
services, associations, lone in-house counsels — and for software agents
that need a documentary source rather than a memory.

Three layers: **authentic texts** (source of truth, never generated,
versioned in time), a **wiki of situations and practice** compiled by a
curator agent under a legal schema and reviewed by a human referent, and a
**search** (lexical first, semantic next) that returns anchored items only.
The engine (this repository) and the knowledge (a text-only repository:
raw sources, compiled pages, curator schema, question bench) are separate.

Four interfaces: an MCP server, a command line, an HTTP API, and an agent
skill.

Greffier is not legal advice: it provides a sourced, dated documentary aid;
the human reader remains the author of their own assessment.

Status (November 2026): scoping. Founding decisions are taken (ADR-0001,
ADR-0002), the first need and its requirements are proposed, no code yet.
French is the normative language of this repository; see `README.md`.

Owner: Eric Lemesre. Licence: [EUPL 1.2](LICENSE).
