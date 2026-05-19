# voska/multica — internal fork

Internal fork of [multica-ai/multica](https://github.com/multica-ai/multica) for Voska org use only.

License: Multica is **modified Apache 2.0** — internal use within a single organization is explicitly permitted. SaaS resale and product-embedding require a commercial license. We do neither, so we're in the clear.

## Branch model

| Branch | Role |
|---|---|
| `main` | Voska's fork. CI auto-merges from `upstream` daily when there are no conflicts. Manual work, fork-specific patches, and feature branches all target `main`. |
| `upstream` | Pristine mirror of `multica-ai/multica:main`, force-updated daily by the mirror job. Never push directly. |

Daily flow:

```
        ┌───── github multica-ai/multica:main ─────┐
        │              (force-mirror)              │
        ▼                                          
  upstream branch  ──merge ff or 3-way──► main branch
                       (if no conflicts)
```

If the auto-merge hits a conflict, the mirror job leaves `main` untouched, pushes the updated `upstream` branch + new tags, and fails the pipeline so you get an email. Resolve manually:

```bash
git fetch
git checkout main
git merge upstream     # resolve conflicts
git push origin main
```

## Working in this repo

1. Branch from `main` for fork-specific changes: `git checkout -b voska/<feature>`
2. PR back to `main` like any other repo
3. Don't touch `upstream` — it's owned by the mirror job

## Mirror schedule

CI Schedule: daily at 06:00 UTC. Manual trigger via Build → Pipelines → "Run pipeline" with `JOB=mirror`.

## Setup (already done, here for reference)

1. Created project at `voska/multica` (private)
2. Seeded `main` + `upstream` from `multica-ai/multica:main`, pushed all upstream tags
3. SSH deploy key with **write_repository** scope stored as the masked CI variable `SSH_DEPLOY_KEY`
4. CI schedule: cron `0 6 * * *`, variable `JOB=mirror`
