# Open-source readiness

Proposal of 14 September 2026, for the maintainer to accept or change: keep **this repository private** for the whole ecosystem and **publish NTO Studio and the shared contracts as a separate open-source repository** when the local workflow is validated. The web integration, Cloud services and operations would remain private here and could be opened later on the owner's terms. The community files in this repository (CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, TRADEMARKS, templates) are drafts for the same decision.

This page tracks readiness for that public Studio repository. It refines the release gate in [ECOSYSTEM-STRATEGY.md](ECOSYSTEM-STRATEGY.md) and the owner's repository requirements (master context §28–33).

## Repository split

| Goes public (Studio repository) | Stays private (this repository) |
| --- | --- |
| `apps/studio` (Xcode project and `NTOFoundation`) | `apps/web` |
| `packages/shared-types` (schema, TypeScript, fixtures) and `packages/design-tokens` | `services/cloud` |
| `scripts/generate-swift-models.py`, `scripts/generate-tokens.mjs` | Strategy documents: `MASTER-CONTEXT.md`, `ECOSYSTEM-STRATEGY.md`, `BUILD-ROADMAP.md` (private GDD references, pricing hypotheses) |
| Docs that describe Studio: ARCHITECTURE (Studio sections), RENDERING, PRESETS, SETUP (Studio parts), STATUS (Studio), phase records, DESIGN-SYSTEM | Cloud and web sections of ARCHITECTURE and SETUP; container scripts |
| CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, TRADEMARKS, issue and PR templates, a Studio-only CI workflow | Web and Cloud CI jobs |

The contracts must live in the public repository because Studio's generated models come from them. This private repository then consumes them (a git submodule or a pinned copy with the existing drift check) so the web and Cloud sides cannot diverge silently.

Studio is the client of the future Cloud, so its sign-in, upload and sync code will be public when written; what stays private is the server implementation and operations.

## Done in this repository (carries over to the public one)

| Requirement | State |
| --- | --- |
| README explains the product, status, requirements | Done; the public README will be Studio-focused |
| CONTRIBUTING.md: scope, ground rules, setup, review, DCO sign-off | Done (DCO chosen as the lightweight default) |
| SECURITY.md with a private reporting route | Done, using GitHub private vulnerability reporting |
| CODE_OF_CONDUCT.md | Done, Contributor Covenant 2.1; enforcement contact placeholder remains |
| TRADEMARKS.md separating code licence from the NTO name, logo, nto.motion and official services | Done as a policy statement, not a legal claim |
| Issue templates and a pull request template | Done |
| Maintained docs: architecture, rendering semantics, preset format, setup, status, per-phase verification | Done |
| No secrets, hosted credentials, signing material or personal photographs in the tree or history | Checked: none found |
| No personal filesystem paths or machine-specific assumptions in tracked files | Done; machine notes live in the git-ignored `CLAUDE.local.md` |
| Feature scope of the recommended v0.1 milestone (§28) exists in code | Done and locally verified (see [STATUS.md](STATUS.md)) |
| Studio CI job on a valid hosted label (`macos-26`) | Runs on GitHub; the web and Cloud jobs pass. The Studio job failed once on a 10,000-record timing assertion that the hosted runner cannot meet; the budget is now environment-aware |

## Maintainer decisions still required

1. **Repository visibility.** It is currently public. Only the owner account can change it (repository Settings → Danger zone → Change visibility, or `gh repo edit Nathan-Olivier/NTO --visibility private --accept-visibility-change-consequences` after `gh auth login` as the owner). Note that the history already published includes the web shells and Cloud migrations; they contain no secrets.
2. **Licence** for the public Studio repository. Add `LICENSE` there; MPL 2.0 is the candidate, with explicit approval and possibly legal review first.
3. **Conduct contact.** Replace the placeholder in CODE_OF_CONDUCT.md.
4. **Brand terms.** Confirm TRADEMARKS.md or replace it with formal terms.
5. **Contribution terms.** DCO sign-off as written, or a CLA if you want to relicense later.
6. **What the public repository is called and where it lives** (organisation or personal account), and its GitHub settings: private vulnerability reporting, branch protection, required checks.

## Creating the public Studio repository (when asked)

1. Create the new repository from the paths in the table above, with fresh history or a filtered history (`git filter-repo --path apps/studio --path packages …`); decide which.
2. Write a Studio-focused README and a Studio-only CI workflow; drop the Cloud and web jobs and the container scripts.
3. Add LICENSE and the package manifest `license` fields.
4. Point this repository at the published contracts package and keep the drift check.
5. Confirm CI green on GitHub for the Studio job, then have a second person clone, build, import, edit and export following SETUP.md.
6. Tag `v0.1.0` after real-shoot validation and the live UI checks listed in the Phase 05–07 records.

## Not required, but worth knowing

- The web app is a fixture-backed shell and is not part of the public release.
- The commit history is short and clean apart from one work-in-progress message.
- The `apps/web/AGENTS.md` block is regenerated by Next.js and is expected.
