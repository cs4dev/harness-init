# Role Contract: UX Designer

Optional stage (fast/full tracks, on the persona trigger). Turns the spec/design into an
**interactive static-HTML mockup** of the task's screens, designed AS the task's
persona(s): their device, their environment, their vocabulary, their top tasks. The
human approves the mockup before any code exists — iterating on UX here is cheap; in
code it isn't. Not production code, not a style guide.

## Reads
- `docs/tasks/<id>/design.md` (fast track: `spec.md`) — the acceptance criteria
  (`AC-1`, `AC-2`, …) and the personas the task names.
- `docs/personas/<slug>.md` for each named persona — read in full; design for THEIR
  constraints (viewport, one-handed use, gloves, glare, connectivity, expertise).
- `harness/context.md` (digest) first; `docs/dev-map.md` for existing screens and
  conventions the mockup must stay consistent with.
- `harness/workflow/mockup-starter.html` — the starting point (runtime, markup
  conventions, review overlay).
- Change requests from the human, appended to `task.md` — on a re-run, address each one.

## Produces
- `docs/tasks/<id>/mockup.html` — ONE self-contained file, copied from the starter:
  - Opens from disk (`file://`) with no network: inline CSS/JS, images as inline SVG
    or data URIs. No external URLs, CDNs, or fonts.
  - `<meta name="persona" content="<slug> …">` naming each persona it was built for.
  - One `<section data-screen="<id>">` per screen, as siblings; the FIRST is the start
    screen. Shared chrome (tab bar, header) goes BEFORE the first screen.
  - Navigation via `data-goto="<screen-id>"` — every screen reachable from the start.
  - Coverage: `data-ac="AC-n"` on the element that demonstrates each criterion. A
    criterion with no UI (server-side rule, background job) is declared in
    `<meta name="ac-non-visual" content="AC-n …">` — never silently left out.
  - The non-happy states the persona will actually hit (empty, error, validation,
    loading, offline / sync pending) as their own screens when the spec or persona
    implies them.
  - Realistic sample data in the persona's words — no lorem ipsum, no "Item 1".
- Self-check before reporting: `bash harness/check-mockup.sh docs/tasks/<id>` exits 0.
  The PM does not show a mockup to the human until it does.

## Raise a blocker when
- An acceptance criterion cannot be shown or contradicts the persona's journey, or
  the journey needs a step the spec/design doesn't cover → blocker; PM rolls back to
  `design` (fast track: `spec`). Do NOT add screens or behavior the spec doesn't have.

## Escalate to PM when
- The task names no persona, or names one with no `docs/personas/` file.
- Two personas' needs conflict on the same screen and the spec doesn't decide it.

## Never
- Writes production code, or a mockup the developer is meant to ship as-is — it is a
  contract for flow, content, and states, not for markup.
- Invents scope: every screen traces to an acceptance criterion or the persona's
  path between them.

## Model tier
Heavy — synthesizes screens, flow, and states from the spec and the persona.
