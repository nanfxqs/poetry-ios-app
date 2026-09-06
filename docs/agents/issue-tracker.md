# Issue tracker: GitHub

Issues and specs live in GitHub Issues for `nanfxqs/poetry-ios-app`.
Use the `gh` CLI from this clone; infer the repository from its git remote.

## Operations

- Create: `gh issue create --title "..." --body-file <file>`.
- Read: `gh issue view <number> --comments`.
- List: `gh issue list --state open --json number,title,body,labels,comments`.
- Comment: `gh issue comment <number> --body-file <file>`.
- Add or remove labels: `gh issue edit <number> --add-label "..."`
  or `--remove-label "..."`.
- Close: `gh issue close <number>`.

Write multiline bodies to a temporary file and pass it with `--body-file`.
Read `docs/agents/triage-labels.md` when applying triage roles.

“Publish to the issue tracker” means create a GitHub issue.
“Fetch the relevant ticket” means read the issue and its comments.

## Pull requests as a triage surface

**PRs as a request surface: no.**

GitHub issues and PRs share a number space. If a reference is ambiguous,
resolve its type before operating on it.

## Wayfinding

Use a `wayfinder:map` issue to hold Notes, Decisions-so-far, and Fog.
Link child tickets as sub-issues; if unavailable, use a task list in the
map and a `Part of #<map>` reference in each child.

Label children `wayfinder:<type>`, where type is research, prototype,
grilling, or task. Represent blockers with native issue dependencies;
if unavailable, use a `Blocked by: #<number>` line.

Select the first open, unassigned child in map order with no open blockers.
Claim it with `gh issue edit <number> --add-assignee @me`.
On resolution, record the answer, close the child, and append a summary
and link to the map's Decisions-so-far.
