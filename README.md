# Claude Code CLI in Docker

Runs the [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) CLI
inside a container, with your project folder bind-mounted so Claude Code can
read and edit your actual source files.

## Files

- `Dockerfile` – Node 22 base image + `@anthropic-ai/claude-code` installed globally, running as a non-root user. Also bakes in a global `CLAUDE.md` and the project scaffold templates. Entrypoint seeds the mounted project, then defaults to `sleep infinity` so the container stays up for `exec`/attach.
- `docker-entrypoint.sh` – runs on every container start: copies `CLAUDE.md`, `.claude/settings.json`, and `.claude/commands/plan.md` into the mounted `PROJECT_PATH` **only if each file doesn't already exist there** — never overwrites anything you've customized.
- `templates/project/` – the authoritative source for those three scaffold files, baked into the image at `/opt/claude-templates/project` and used by the entrypoint script. Edit these (then rebuild) to change what gets seeded into *new* projects.
- `claude-global/CLAUDE.md` – standing instructions that apply to every project: plan-first workflow, mandatory Vitest tests, documentation requirement, session-handoff/`PROGRESS.md` requirement, default ask-vs-decide judgment calls. Copied into the image at `~/.claude/CLAUDE.md`.
- `docker-compose.yml` – builds the image, mounts `${PROJECT_PATH:-./project}` into `/workspace`, and persists Claude Code's config/auth in a named volume.
- `.devcontainer/devcontainer.json` – lets VS Code's Dev Containers extension build/attach to this same compose service directly.
- `.env.example` – template for your API key, mount paths, and host UID/GID.
- `project/` – example/default mount target when `PROJECT_PATH` is unset. Since the entrypoint auto-seeds these files now, you generally don't need to hand-copy anything into your real project — just point `PROJECT_PATH` at it and start the container.

## Setup

1. Copy the env template and fill it in:

   ```bash
   cp .env.example .env
   ```

   At minimum, set `ANTHROPIC_API_KEY`. Two other vars matter for the mounts:

   - `PROJECT_PATH` – path to your actual project (relative to the compose
     file, or absolute). Defaults to `./project` if left unset.
   - `CLAUDE_CONFIG_PATH` – where Claude Code's config/auth/session history
     lives. Leave unset (recommended) to use the `claude-config` named
     Docker volume. Set it to a host path (e.g. `./claude-config`) instead
     if you want those files directly visible/backupable on your machine.

   (Optional) Run `id -u` / `id -g` on your host and set `USER_UID` /
   `USER_GID` in `.env` to match, so files Claude Code creates aren't
   owned by a mismatched UID on your host.

   > Note: the base `node:22-slim` image already has a built-in `node`
   > user/group at UID/GID 1000. The Dockerfile detects if your requested
   > `USER_UID`/`USER_GID` collides with an existing account and renames it
   > to `claude` rather than failing with `groupadd: GID '1000' already
   > exists` — so 1000 (the default) works fine, as would any other value
   > that happens to match an existing system account.

2. Build the image:

   ```bash
   docker compose build
   ```

## Usage

The entrypoint script seeds any missing scaffold files into `/workspace`
(your mounted project) on every start, then hands off to whatever `CMD` is
— by default `sleep infinity`, so the container stays running for `exec`.

**Start it:**
```bash
docker compose up -d
```

**Run Claude Code inside it:**
```bash
docker compose exec claude-code claude              # interactive session
docker compose exec claude-code claude -p "add a .gitignore for Python"
docker compose exec claude-code bash                 # plain shell, if you want one
```

**Stop it when done:**
```bash
docker compose down
```

Because `/home/claude/.claude` is a named volume, authentication and session
history persist across restarts — you shouldn't have to log in every time.

> Note: `docker compose run --rm claude-code claude -p "..."` also works
> now (it didn't in an earlier version of this setup) — the entrypoint
> script seeds files then `exec`s whatever command you pass, rather than
> the container's `ENTRYPOINT` being `sleep infinity` directly. `run`
> starts a fresh, throwaway container per invocation; `exec` runs inside
> the already-running one from `docker compose up -d`. Either works; `exec`
> is marginally faster since there's no new container startup.

## Working from VS Code (Dev Containers)

This repo includes `.devcontainer/devcontainer.json`, which points at the
same `docker-compose.yml` so VS Code can build/attach to it directly.

1. Install the **Dev Containers** extension in VS Code.
2. Open this folder (the one containing `.devcontainer/`) in VS Code.
3. Command Palette → **Dev Containers: Reopen in Container**.
   VS Code will build the image (if needed), start the compose service,
   and open a window rooted at `/workspace` inside the container.
4. Open a terminal in that VS Code window — you're now in the container.
   Run `claude` directly; no `docker compose exec` needed since the
   terminal is already inside it.

Your actual workflow, end to end:

1. Open VS Code, open your project folder (the one containing
   `docker-compose.yml` / `.devcontainer/`).
2. **Reopen in Container** (VS Code handles build + `up` for you —
   you don't need to manually run `docker compose up -d` first).
3. Use the integrated terminal inside that container window and run
   `claude` there.

If you'd rather not use the Dev Containers extension at all, the manual
equivalent is:
```bash
docker compose up -d
docker compose exec claude-code bash
# then inside that shell:
claude
```

## Customizing Claude Code's instructions

- **`claude-global/CLAUDE.md`** (baked into the image, applies to every
  project): workflow style, testing requirements, documentation
  requirement, session-handoff/`PROGRESS.md` requirement, default judgment
  calls. Edit this file, then `docker compose build` to pick up changes.
- **`templates/project/CLAUDE.md`** (baked into the image, seeded into new
  projects): the default project-level `CLAUDE.md` a fresh project starts
  with (Project Goal, stack, style sections to fill in). Edit this, then
  rebuild, to change what *new* projects get. Editing the copy already
  seeded into a project's `/workspace` doesn't need a rebuild.
- **`.claude/commands/plan.md`**: type `/plan add user auth` inside a Claude
  Code session to explicitly trigger the plan-first workflow for a task. It
  also seeds/updates `PROGRESS.md` once the plan is confirmed.
- **`.claude/settings.json`**: adjust the `allow`/`deny` lists as you learn
  which commands you're comfortable letting Claude Code run unprompted.
  Double check the current permission-rule syntax against
  https://docs.claude.com/en/docs/claude-code/overview if it's been a while
  since this was written — the format may have evolved.

### Auto-seeding scaffold files into your project

On every container start, `docker-entrypoint.sh` copies `CLAUDE.md`,
`.claude/settings.json`, and `.claude/commands/plan.md` from
`templates/project/` (baked into the image) into whatever's mounted at
`/workspace` — **only for files that don't already exist there**. So:

- A brand-new empty project gets all three scaffold files automatically the
  first time you start the container against it — no manual copying needed.
- An existing project that already has its own `CLAUDE.md` (or the other
  files) is left completely alone; the entrypoint only fills gaps, never
  overwrites customizations.
- This runs every start, so it's safe/idempotent — deleting one of the
  three files from your project and restarting the container will
  re-seed just that one file, without touching the others.

### `PROGRESS.md`: picking up where you left off

The global instructions ask Claude Code to maintain a `PROGRESS.md` at your
project root: written when a plan is confirmed, updated after each step. If
you step away for a while, opening `PROGRESS.md` should tell you what was
planned, what's done, what's next, and any open questions — without having
to scroll back through chat history. This file isn't auto-seeded (there's
nothing generic to seed — it only makes sense once real work has started);
Claude Code creates it itself the first time you confirm a plan.

> **Volume-seeding caveat:** the named `claude-config` volume is only
> pre-populated from the image's `~/.claude` directory the *first* time that
> volume is created. If you already have an existing `claude-config` volume
> from before adding the global `CLAUDE.md`, a rebuild alone won't retroactively
> add it — remove the old volume first (`docker compose down -v`, which also
> wipes stored auth) or copy the file in manually
> (`docker compose exec claude-code sh -c "cat > ~/.claude/CLAUDE.md"`
> with the content piped in). If you set `CLAUDE_CONFIG_PATH` to a bind-mount
> host path instead, the image's copy is never used at all — copy
> `claude-global/CLAUDE.md` to that host path yourself.

## Notes / things to double check for your setup

- **Auth**: This assumes API-key auth (`ANTHROPIC_API_KEY`). If you'd rather
  log in interactively with a Claude.ai/Console account instead of an API
  key, just run `docker compose run --rm claude-code` with no key set and
  follow the login prompt — the named volume will persist that login too.
- **Permissions prompts**: Claude Code normally asks before editing files or
  running commands. In a throwaway container this is usually fine to allow;
  if you want it to skip prompts entirely you can add
  `--dangerously-skip-permissions` to the command, but only do this for
  containers where you're comfortable with unattended file/command access.
- **Network access**: If your project needs to install dependencies (npm,
  pip, etc.) during the session, make sure the container has network access
  (default bridge networking is on unless you've changed it).
- **Package manager**: `pnpm` is available via Corepack (pinned to pnpm 9 in
  the Dockerfile), and the project `CLAUDE.md` template defaults to it. Some
  scaffolding CLIs default to npm output unless told otherwise — e.g.
  `create-next-app` needs an explicit `--use-pnpm` flag to generate a
  pnpm-based project instead of npm. If you'd rather use npm or yarn for a
  given project, just change the "Package manager" line in that project's
  `CLAUDE.md`.
- Verify the Node version requirement and install method still match current
  Claude Code docs before relying on this long-term:
  https://docs.claude.com/en/docs/claude-code/overview
