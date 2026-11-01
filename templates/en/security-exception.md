# Security exception — {{ CVE identifier / finding }} — YYYY-MM-DD

<!-- A risk acceptance is explicit, versioned, owned and dated — never tacit
     (method, ch. 10). Use the tool's native format when it exists (audit
     ignore-list, .gitleaks.toml) with a link back to this record for the
     full justification. -->

- **Subject**: {{ CVE-YYYY-NNNN, scan finding, or false positive }}
- **Component concerned**: {{ dependency and version, file }}
- **Announced severity**: {{ critical / high / medium / low }}

## Justification

{{ Why the risk is acceptable HERE: vulnerable function not used, component
not exposed, compensating control in place… "We'll see later" is not a
justification. }}

## Ownership

- **Owner**: {{ name — the person accountable for this risk }}
- **Review deadline**: {{ YYYY-MM-DD — mandatory; an exception without a
  deadline is invisible debt }}
- **Lifting condition**: {{ fix released, version bump, component removal… }}
