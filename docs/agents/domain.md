# Domain docs

## Before exploring

Read the root `CONTEXT.md` and relevant decisions in `docs/adr/`.

If they do not exist, proceed silently. Domain modeling creates them
when domain terms or decisions are resolved.

## Layout

This is a single-context repository:

- `CONTEXT.md`: domain model and glossary.
- `docs/adr/`: numbered architecture decision records.

## Vocabulary

Use the terms defined in `CONTEXT.md` in issue titles, proposals,
hypotheses, and test names. If a needed concept is missing, reconsider
the wording or note the gap for domain modeling.

## Decision conflicts

Explicitly identify any proposal that contradicts an existing ADR,
including the ADR reference and the reason to reconsider it.
