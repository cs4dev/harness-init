# Persona — {{PERSONA_NAME}}

> One file per persona: `docs/personas/<slug>.md`, where the slug is what tasks and
> mockups cite (`<meta name="persona" content="<slug>">`). Written from the interview,
> not invented. Keep it to one screen; it's read in full by every UI task's
> ux-designer and by QA's persona walkthrough. Retire a persona by marking it
> RETIRED at the top, never by deleting the file (old mockups still cite it).

**Who:** {{PERSONA_WHO}}
<!-- e.g. "Field technician: HVAC/plumbing, 2–15 yrs on the tools, 5–8 jobs a day across sites" -->

**Device + viewport:** {{PERSONA_DEVICE}}  ·  mockup `data-device`: {{PERSONA_VIEWPORT}}
<!-- e.g. "Company Android phone, one hand, often in a case with gloves on" · phone -->

## Context of use
<!-- The environment that shapes the UI. Each line should change a design decision. -->
- {{PERSONA_CONTEXT}}
<!-- e.g. bright sun on rooftops (contrast) · gloves (≥48px targets, no small toggles)
     · basements with no signal (offline queue, visible sync state)
     · customer watching over their shoulder (no internal jargon on shared screens) -->

## Top tasks (in order of frequency)
1. {{PERSONA_TASK_1}}
<!-- e.g. 1. See today's jobs and pick the next one  2. Get to site: address, gate code, contact
     3. Log work, parts, photos  4. Get the customer's sign-off  5. Close the job -->

## Words they use / avoid
<!-- Their vocabulary for labels and sample data: "job", not "work order entity";
     "parts", not "inventory line items". -->
- {{PERSONA_VOCABULARY}}

## Must never happen
<!-- The persona-level failures that would make them stop using the app. -->
- {{PERSONA_NEVER}}
<!-- e.g. losing a completed job because signal dropped · re-typing what the dispatcher already entered -->
