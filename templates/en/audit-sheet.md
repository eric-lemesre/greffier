# Audit — {{ domain }}

<!-- Mirrors spec/02-exigences/{{ domain }}.md. Verdicts are written BY HAND:
     this is the judgement no gate can pass. The dashboard
     docs/audit/README.md is generated — do not edit it.
     Skeleton for missing rows:
       sh tools/audit.sh --squelette {{ domain }} -->

Allowed verdicts: `compliant` · `gap` · `not examined`.

| Requirement | Verdict | Evidence / gap |
| --- | --- | --- |
| `req~identifier~1` | compliant | {{ file, gate or test that shows it }} |
| `req~another~1` | gap | {{ how the delivered behaviour departs from the statement }} |
| `req~one-more~1` | not examined | |

<!-- A "compliant" without evidence is a claim, not an audit.
     A "gap" without a description is an unusable finding. -->

## Open gaps

- {{ req~… — what is missing, and what is decided: fix, requirement to
     revise, or accepted gap with its rationale }}
