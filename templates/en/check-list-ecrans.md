# Agent screen-review checklist

<!-- Version this in the project repository (docs/verification-manuelle/
     or equivalent) and walk through it at stage 3 of screen validation
     (docs/methode/16-validation-des-ecrans.md). Adapt the items to the
     domain; never remove one without recording the decision. -->

## Per screen

1. **Language**: everything is in the user's language, correct; no
   technical identifier leaks onto the screen.
2. **Labels**: consistent with the reference data and across screens (the
   same concept bears the same word everywhere).
3. **No mute states**: empty, loading and error states say what to do.
4. **Hierarchy**: one title per screen, readable sections, the main
   action stands out.
5. **Density**: nothing truncated at the reference viewport, no
   horizontal overflow.
6. **Safe usage**: destructive or committing actions are unambiguously
   named; whatever is irreversible says so.
7. **Sensitive data**: no secret nor out-of-scope data on screen.

## Cross-cutting

1. Every delivered screen has its journey in the matrix (no screen
   without a capture); otherwise, complete the matrix BEFORE the sheet.
2. Accessibility findings that do not gate are read and recorded when
   they touch a main journey.
3. Every non-blocking reservation is recorded with its due date (debt),
   never silenced.
