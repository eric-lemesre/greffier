# Code review — {{ branch or requirement }} — YYYY-MM-DD

<!-- Archive in docs/revues/. The reviewer is a human peer or an AI model
     different from the one that produced the code. -->

- **Scope**: {{ diff reviewed, requirements concerned }}
- **Reviewer**: {{ human, or model used }}
- **Overall verdict**: {{ approved / approved with reservations / rejected }}

## Findings

| # | Severity | Finding | Verdict | Resolution |
| --- | --- | --- | --- | --- |
| 1 | high / medium / low | {{ description, file:line }} | Fixed / Rejected | {{ commit, or rejection reason }} |

<!-- Rules: no finding left unanswered; high severity fixed in the same branch
     before merge; general lessons are promoted into rules (mechanical gate or
     agents contract) with a reference to this review. -->

## Checks beyond findings

- EARS compliance of new or changed requirements: {{ ok / n-a }}
- No convenience tagging (tagged code actually realises the requirement): {{ ok }}
- Test level matches the declared Needs: {{ ok }}
