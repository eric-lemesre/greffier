# Requirements — {{ domain }} domain

**Status: PROPOSED** — becomes ACTIVE when a register decision enacts it.

<!-- Goes into spec/02-exigences/. One file per functional domain. -->

## {{ Readable requirement title }}

`req~kebab-name~1`
Status: draft

**Status: draft**

<!-- Declared: draft · proposed · approved · rejected · deprecated.
     NEVER declared: "implemented" and "verified" — they are COMPUTED from the
     coverage actually present, and the gate refuses them if written by hand.
     A requirement is only approved within an active domain (ADR-0018).
     The "Status: …" line RIGHT UNDER the identifier is read by
     OpenFastTrace: draft, proposed, rejected (rejected, deprecated); REMOVE
     it on approval. Traceability only keeps approved items, and
     tools/statuts.sh checks both statuses agree (ADR-0021). -->

{{ EARS phrasing with SHALL / SHOULD / MAY normative level:
- Ubiquitous: The system SHALL …
- Event-driven: When <trigger>, the system SHALL …
- State-driven: While <state>, the system SHALL …
- Unwanted behaviour: If <unwanted condition>, then the system SHALL …
- Optional feature: Where <feature is present>, the system SHALL … }}

Rationale:
{{ Justification, when the motive is not obvious. }}

Acceptance criteria:

- Given {{ context }}, when {{ action }}, then {{ verifiable outcome }}.
- Given {{ adverse case }}, when {{ action }}, then {{ expected behaviour }}.

Covers:

- feat~parent-need~1

Needs: impl, utest

<!-- Needs according to the declared verification level: dsn when a design
     decision is expected; utest / itest / stest / mtest depending on the test
     level (method, ch. 5). -->
