# Global Instructions for Claude Code

These apply across every project (baked into the image at
`~/.claude/CLAUDE.md`). Project-specific details — goal, stack, style —
live in each project's own `CLAUDE.md` instead.

## Workflow: Plan → Confirm → Execute Step by Step

Before writing or modifying code for any non-trivial task:

1. **Write a plan first.** Break the work into a numbered list of concrete
   steps. Post the plan before touching any code and wait for confirmation
   or adjustment — don't start implementing until I've signed off.
2. **Track progress visibly.** Use your task-tracking (todo list) so I can
   see which step is in progress, done, or pending at a glance. Update it as
   you go, not just at the end.
3. **Work one step at a time.** After finishing a step, stop and give a
   short summary of what changed before moving to the next one — don't chain
   through the whole plan silently.
4. **Expect sub-prompts mid-step.** I may interject with feedback,
   corrections, or a smaller side-task in the middle of a step. Handle it,
   then return to the plan where we left off rather than restarting it.
5. **Re-plan out loud if scope changes.** If something discovered mid-way
   means the original plan no longer makes sense, say so explicitly and
   propose an updated plan rather than quietly deviating from it.

Use `/plan <task>` as a shortcut to explicitly kick off step 1 for a new
piece of work (see `.claude/commands/plan.md` in each project).

## Session Handoff / Progress Log

Maintain a `PROGRESS.md` at the project root so that coming back to a
project after time away (a long weekend, a different session) means reading
one file to know exactly where things stand — not re-deriving it from git
history or chat scrollback.

- **When a plan is confirmed** (per the workflow above), write or update
  `PROGRESS.md` with:
  - The confirmed plan, as a checklist (`- [ ]` / `- [x]`).
  - A one-line statement of the current goal/task this plan belongs to.
- **After each step completes**, update `PROGRESS.md`:
  - Check off the completed step.
  - Add a short note of what was actually done (a sentence or two — not a
    full diff summary, just enough to reorient quickly).
  - Note anything left mid-way, any open questions, or decisions that were
    deferred, so the next session starts with context instead of guessing.
- **Keep it current, not historical.** `PROGRESS.md` reflects where things
  stand *now*. If a step's plan changed after starting it, update the entry
  rather than leaving a stale description next to a checked box. Long-term
  history belongs in git commits/PRs, not this file.
- **At the start of a session**, if `PROGRESS.md` exists and shows
  in-progress or pending work, read it first and confirm with me whether to
  resume where it left off before starting anything new.

## Testing Requirement

- **Every piece of generated or modified code must come with Vitest tests.**
  If you add a function, component, or module, add or update the
  corresponding `*.test.ts` / `*.test.tsx` file in the same change — don't
  treat tests as a follow-up step.
- Tests should cover the normal case plus at least one edge case / failure
  case, not just a happy-path smoke test.
- If a test can't reasonably be written (e.g. pure config, trivial
  re-export), say so explicitly rather than silently skipping it.
- Run the test suite after making changes and report the result — don't
  assume it passes.

## Documentation Requirement

- **Keep user-facing documentation up to date for every project** — a
  README (or `docs/` folder for anything beyond a single page) that covers:
  - **Setup**: how to install/run the project from a clean checkout
    (dependencies, env vars, build/start commands).
  - **Features**: what the project can currently do, kept in sync as
    features are added — not just what was true at project start.
  - **Usage**: concrete instructions/examples for each feature — commands,
    API calls, UI flows, or config options, whichever fits the project.
- **Update docs in the same change as the feature**, not as a deferred
  follow-up. If you add or change a feature, update the relevant doc section
  before considering that step done.
- If a change is purely internal (refactor, test, fix with no user-visible
  behavior change), documentation updates aren't required — use judgment,
  and say explicitly why you're skipping it if it's not obvious.
- If no user-facing docs exist yet for a project, treat creating that
  initial doc as part of the setup/plan for the first feature, not
  something to defer indefinitely.

## Default Judgment Calls

Unless a project's own `CLAUDE.md` overrides these:

**Always ask first about:**
- Anything touching authentication, payments, or data deletion.
- Adding a new external dependency.
- Any change requiring a database migration or schema change.

**Fine to decide without asking:**
- Formatting, renaming for clarity, adding comments/docstrings.
- Writing the tests required above.
- Writing/updating user-facing documentation for changes you made.
- Small refactors that don't change behavior.

**Git:** leave changes staged for review by default — don't commit
automatically unless a project's `CLAUDE.md` says otherwise or I ask you to.