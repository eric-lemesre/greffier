# Threat model — {{ requirement or flow }} — YYYY-MM-DD

<!-- Short format (30-60 min, as a team). Mandatory for S-level requirements
     and any new data boundary (method, ch. 10). Mandatory outcome: retained
     threats become acceptance criteria of the requirement. -->

- **Requirement(s) concerned**: {{ req~identifier~n }}
- **Participants**: {{ names }}

## The flow

{{ Components, data exchanged, trust boundaries — three sentences or a
diagram. What comes in, what goes out, who is allowed to talk to whom? }}

## Threats examined (STRIDE)

| Category | Threat identified | Priority | Decision |
| --- | --- | --- | --- |
| S — spoofing | {{ … or "none identified" }} | critical/high/medium/low | acceptance criterion / ADR mitigation / risk accepted |
| T — tampering | {{ … }} | | |
| R — repudiation | {{ … }} | | |
| I — information disclosure | {{ … }} | | |
| D — denial of service | {{ … }} | | |
| E — elevation of privilege | {{ … }} | | |

## Outcomes

- Acceptance criteria added to {{ req~identifier~n }}: {{ list }}
- Structural decisions to enact: {{ ADR to open, or none }}
- Accepted risks: {{ link to the versioned exception, or none }}
