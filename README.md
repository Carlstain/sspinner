# SSpinner

Global launcher for multi-repo local dev stacks. You register a project once
— its services, where they live, and how each one is run (`docker compose`,
`yarn`, `pnpm`, `poetry`, or any custom command) — and from then on boot the
whole thing from anywhere with one command:

```bash
sspinner run myapp
```

Each service gets its own window with its actual live output (docker compose
logs, Vite/webpack output, whatever it prints), started in the order you
registered them, each one waited on before the next starts if you gave it a
port. Windows open in [Terminator](https://gnome-terminator.org/) if it's
installed (a real split-pane grid in one window), falling back to your
default terminal emulator (one window per service), falling back to a plain
sequential mode with no windows at all. A shared Dozzle container gives a
web-based view of every project's docker logs regardless of which one is
currently running.

<p align="center"><img src="images/sspinner-help.png" width="640" alt="sspinner --help output"></p>

## Install

```bash
git clone git@github.com:Carlstain/sspinner.git ~/tools/sspinner
~/tools/sspinner/install.sh
```

This symlinks `sspinner` onto `~/.local/bin`, wires up shell completion (see
below), and checks for `docker` (required) and a terminal backend (optional —
`terminator` is recommended for the nicest split-pane grid; otherwise `run`
opens one window per service in whatever terminal emulator your desktop
already defaults to; it falls back to a sequential, no-window mode only if
neither is found).

## Shell completion

`install.sh` adds a sourcing line to `~/.bashrc` and/or `~/.zshrc` (whichever
exist) — open a new shell afterward and `sspinner <TAB>` completes
subcommands, `sspinner run <TAB>` completes registered project names (pulled
live from the registry), and `sspinner infra <TAB>` completes `up`/`down`.
The scripts live in `completions/` if you want to source them manually
instead.

## Commands

```bash
sspinner register <project>            # interactive: add services one at a time
sspinner register <project> --from <src>  # clone an existing project's services
sspinner edit <project>                # menu on a tty, raw $EDITOR otherwise
sspinner list                          # show every registered project + live status
sspinner status <project> [--json]     # just one project's status
sspinner run <project>                 # boot it: one window per service, in order
sspinner run <project> --only a,b      # boot just these services
sspinner run <project> --except a      # boot every service except these
sspinner run <project> -b              # boot it in the background: no window at all
sspinner restart <project> [svc...]    # tear down then boot, optionally scoped
sspinner stop <project>                # tear everything down and verify it's actually gone
sspinner logs <project> [svc]          # tail one service's logs, or the Dozzle URL
sspinner exec <project> <svc> [-c CONTAINER] <cmd>   # shortcut for docker compose exec
sspinner doctor [project]              # read-only preflight: docker, paths, ports, binaries
sspinner infra up / down               # manage the shared Dozzle log viewer directly
```

(`sspinner down <project>` still works as a deprecated alias for `stop`.)

`sspinner list` (and `sspinner status <project>`) show a live status table.
Status cells: green `● running` (port answers, or its docker-compose project
has containers up) / yellow `◐ starting` (containers up, port not answering
yet) / dim `○ stopped` / yellow `◑ foreign` (the port answers but it isn't
this service's own tracked process) — plus, only ever shown mid-boot by
`run`/`restart`: green `◒ already up` (skipped relaunch, it was already up),
red `✗ exited (code)` (the command itself died — reported in ~1-2s, not the
full port timeout), red `✗ timeout`, red `✗ port busy` (something else already
had the port before boot even started), and dim `⊘ skipped` (you pressed `s`
during the wait). Above a ~150-column terminal, `list` lays two projects out
side by side instead of stacking every table vertically:

<p align="center"><img src="images/sspinner-list.png" width="640" alt="sspinner list output showing two demo projects with live status"></p>

### `run -b` boots without taking over your terminal

`-b`/`--background` always runs every service sequentially in the background
with output logged to temp files under the system temp dir, whether or not
Terminator or a terminal emulator is available — both windowed backends open
a GUI window, which is exactly what `-b` exists to avoid. Control returns to
your shell immediately once every service has started (or timed out waiting
on its port). Each service's process is tracked by a pid file under
`~/.config/sspinner/running/<project>/`, so `sspinner stop` can find and kill
it later even without a window or session to tear down.

### `exec` — a shortcut into a running container

`sspinner exec <project> <service> <command>...` is a shortcut for
`docker compose exec` that saves `cd`-ing to the repo and remembering the
pinned `-p` project name — it only works on `docker-compose` services. It
defaults to the container whose compose-service name matches the sspinner
service name; pass `-c/--container <name>` to reach a different one in the
same compose project (e.g. its database):

```bash
sspinner exec myapp back bash                          # shell in the 'back' container
sspinner exec myapp back -c database psql -U postgres  # a sibling container instead
```

If the target isn't running yet, it offers to `run` the project first.
Tab-completion for this command only proposes the project's docker-compose
services (and, after `-c`, that service's own containers) — not every
registered service.

### `register` walks you through each service

For every service it asks:
- **name** (e.g. `back`, `front`, `keycloak`)
- **path** — a live, filterable dropdown of matching directories as you type
  (arrow keys to move, Tab to descend, Enter to accept), falling back to a
  plain prompt if your terminal can't do that
- **how it's run** — `docker-compose`, `yarn`, `pnpm`, `npm`, `poetry`, or
  `custom`. If the path has a `docker-compose.yml`/`package.json`/
  `pyproject.toml`, that runner is floated to the top of the list; for Node
  projects, `package.json`'s `scripts` are offered as a pick-list instead of
  free text. Best-effort port detection pre-fills the port question too.
- **port** to wait on before starting the next service (optional — leave blank
  for a service with nothing to poll, e.g. a background worker)

The follow-up questions after picking a runner (compose project name, script
to run, the shell command for `custom`, ...) all accept Esc to back out and
re-pick the runner, so a wrong choice — or `custom`'s required command
prompt — never traps you.

Register in the order services should start — if you add more than one,
you're offered a chance to reorder them (boot order matters) before saving.
Run it again on an already-registered project to add more services, or start
over from scratch.

Cloning an existing project's shape (`register <name> --from <src>`) copies
its services and asks you to confirm each one's path and port (and, for
docker-compose services, its compose project name) rather than re-answering
every question from scratch.

### Editing later

`sspinner edit <project>` opens a menu on a real terminal — add a service,
remove one, reorder, change the shared network, drop into raw JSON in
`$EDITOR`, or cancel — reusing the same widgets `register` uses. Piped/
non-interactive stdin goes straight to `$EDITOR` on the raw JSON, same as
before. Either way the result is validated before it's saved (unknown
runner, a relative path, a missing required field, a duplicate service name
or port) — a bad edit is refused with the specific problem, not silently
saved to surface later as a crash. You can also edit
`~/.config/sspinner/registry.json` directly — it's plain JSON, one entry per
project.

### `status`, `restart`, `logs`, `doctor`

- `sspinner status <project> [--json]` — just that one project's table
  (`--json` for scripting).
- `sspinner restart <project> [service...]` — tears down then boots again,
  through the exact same teardown/boot code `stop`/`run` use; give it one or
  more service names to restart just those instead of the whole project.
- `sspinner logs <project> [service]` — `docker compose logs -f` for a
  docker-compose service, `tail -f` its log file for anything started via
  `run -b`/the sequential fallback, or just prints the Dozzle URL if you
  don't name a service.
- `sspinner doctor [project]` — read-only preflight, never fixes anything:
  is docker reachable, which backend would `run` pick, and per project per
  service — does the path exist, is there a compose file where a
  docker-compose service expects one, is the runner binary on `$PATH`, is
  the declared port free or already this service's own.

## What `run` actually does

0. If another registered project already has something running (checked by
   whether its compose project has containers up, for docker-compose
   services — a port number alone is checked last and never taken as proof,
   since two unrelated projects can happen to declare the same port), it
   shows a table of what's running and asks what to do: stop the other one
   first, keep it running and start this one too, or cancel. Skipped
   entirely if nothing else is running, and auto-continues (leaving the
   other one running) when stdin isn't a terminal.
1. Makes sure the shared Dozzle container is running
   (`infra/docker-compose.yml`, published at http://localhost:9999 — shows
   live logs for every container on the machine, grouped by compose project).
2. Creates the project's shared docker network if it declared one.
3. `--only a,b` / `--except a` narrow which services boot this time, without
   touching the registered order or the other services' tracked state.
4. Prints one status table — service / runner / detail / url / status — and
   keeps updating it in place as the boot progresses, rather than a wall of
   separate tables and headings. Each service's status cell moves through
   `○ queued` → a spinning `starting (Ns)` → `● running (N.Ns)` (its port
   answered, with how long it took), `● started` (no port to check),
   `✗ exited (code)` (its own command died — caught in ~1-2s, not the full
   port timeout), `✗ timeout` (its port never answered), or `✗ port busy`
   (something else already had the port before this service was even
   started — reported, never killed). `run` moves on to the next service
   after any of these except a user-requested stop. A dim line under the
   table tracks which service is currently starting — with an `s skip · q
   abort` hint — and turns into the `terminator window: ...` / `terminal
   windows: ...` pointer once everything's up (pressing `q` during a wait
   stops the whole boot there instead). If stdout isn't a terminal (piped/
   scripted), there's no animation: the table prints once up front, plain
   `✓ x is up on :port (N.Ns)` lines print as each service finishes, then
   the table prints once more at the end.
5. Opens one window per service in registration order — a Terminator grid
   (at most 2 terminals per row) if it's installed, else one window per
   service in your default terminal emulator, else sequentially in the
   background with output logged to files under the system temp dir (the
   last service, if not `docker-compose`, then runs directly in your
   terminal). Every window/process is tracked by a pid file so `stop` can
   find and kill it later, regardless of which backend started it:
   - `docker-compose` services: `up -d --build` then `logs -f` in the same window
   - everything else: the service's actual run command, directly, in the foreground
   - if the service has a port, `run` polls it before moving on to the next one

Once the boot finishes, a compact relative-duration bar prints under the
table for every service that came up (needs at least two, to have something
to be relative to) — a glance at which one was the slow one instead of
reading back through the table's `● running <N.Ns>` cells.

## Where things live

- **Code** (this repo): `~/tools/sspinner` (or wherever you clone it).
- **Runtime state** (not in git): `~/.config/sspinner/registry.json` — the
  project → services config that every command reads/writes — and
  `~/.config/sspinner/running/<project>/` — one pid file per running
  non-terminator-tracked service (so `stop` can find and kill it later), plus
  a `.rc` sibling written once that service's own command exits, which is
  what lets `run` report a died-instantly service in ~1-2s instead of the
  full port timeout.

See `CLAUDE.md` for the internals if you're editing this tool with Claude Code.
