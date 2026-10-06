# G8 nightly demo

An example repo (`pulse-portal/`) whose nightly pipeline fails phase 2 for three
separate reasons, and a simulator (`simulator/`) that runs that nightly on your
machine so you can watch each fix take effect.

```
pulse-portal/     the example repo, as it would sit in GitLab
simulator/        fake runner, recorded audit output, fix scripts
```

## Run it

Needs `bash`, `jq` and `gitleaks` (8.25 or later) on macOS, Linux or WSL.

```bash
cd simulator
./run-nightly.sh                  # broken: 3 failures
./fix-1-install-npm.sh            # then run-nightly again after each fix
./fix-2-clear-fixtures.sh
./fix-3-record-exceptions.sh      # pipeline is green from here
./fix-4-build-from-lockfiles.sh   # optional, clears the last warning
./reset.sh                        # back to broken
```

`G8_TODAY=2026-10-26 ./run-nightly.sh` runs the nightly as if it were that date,
which shows the exceptions from fix 3 expiring.

## What is real and what is simulated

| Part | Status |
|---|---|
| gitleaks scan, `.gitleaks.toml`, the gate, the docs counter | Real. Your gitleaks and jq run against the repo. |
| The runner | Simulated. A temp directory holding only the tools named in `ci/rules.yml`, used as the whole `PATH`. |
| `npm audit` output | Recorded from the real `npm audit --json` against this `package-lock.json` on 2026-10-06. |
| `composer audit` output | Rebuilt in Composer's JSON shape from Packagist's advisory API on 2026-10-06, trimmed to the fields the gate reads. The advisories and affected ranges are real. |
| `composer.lock` files | Trimmed to one package each. Not installable. |
| Runner layout, job rules, the exceptions policy, the "nightly MR" | My design. Your pipeline will differ in the details. |

## Where things are

| File | Role |
|---|---|
| `ci/rules.yml` | Describes the runner (`RUNNER_TOOLS`) and when each job runs |
| `ci/scripts/phase-02-*.sh` | Scanners. They write `reports/` and never fail on findings |
| `ci/scripts/g8-gate.sh` | G8. Reads the reports and decides |
| `.gitleaks.toml` | Built-in rules plus the six QA dummies, listed by exact value |
| `config/qa.env`, `helm/values-qa.yaml`, `tests/fixtures/qa_users.php` | The six QA dummy secrets |
| `tests/security/log_redaction_security.php` | Three hardcoded tokens that are not allowlisted |
| `ci/dependency-exceptions.json` | Exceptions and the policy that limits them |
| `docs/cicd.md` | Pipeline docs, including a generated counts table that G8 checks |
| `docker/Dockerfile.php` | Runs `composer update` for `modules/aws` and `modules/openai` |

## The three failures

### 1. npm-audit: `npm: command not found`

`ci/rules.yml` lists the runner's tools as docker, helm, composer and cspell.
It is a shell runner, so a job gets what is on the host and nothing else. The
`npm-audit` job only runs on the nightly schedule or when `package-lock.json`
changes, so ordinary merge requests never hit it. The nightly does, the script
exits 127, and no report is written. G8 then fails check 1, because a missing
report means the scanner did not run and that is never counted as clean.

### 2. Secrets: three open findings

The six QA dummies are secret-shaped but each is listed in `.gitleaks.toml` by
exact value, so they are excused and nothing else is. The redaction test has
three more tokens (GitHub, AWS, Slack shapes) that nobody listed. gitleaks
reports them and G8 allows zero open findings.

### 3. Composer: three high/critical advisories

| Component | Package (locked) | Advisory | Severity | Fixed in |
|---|---|---|---|---|
| `application` | guzzlehttp/guzzle 7.15.1 | CVE-2026-69246 | high | 7.15.2 |
| `modules/backup` | league/flysystem 1.1.3 | CVE-2021-32708 | critical | 1.1.4 |
| `modules/surveys` | dompdf/dompdf 2.0.1 | CVE-2023-23924 | critical | 2.0.3 (2.0.2 has its own critical) |

Nine medium and low advisories are also reported and do not block.

**Why these block the nightly MR**

1. **Policy.** G8 fails on any high or critical advisory that has no live
   exception. There were no exceptions.
2. **The nightly is where they surface.** Merge request pipelines only run
   `composer-audit` when a `composer.lock` changes. The nightly audits every
   component every time. The Guzzle advisory was published on 2026-08-03, so a
   lockfile that was clean in July went red with no code change.
3. **Nothing after the gate runs.** `g8-gate` is not `allow_failure`, so the
   pipeline fails and the build and deploy phases are skipped.
4. **GitLab enforces it.** With "Pipelines must succeed" on, a merge request
   whose latest pipeline failed cannot be merged. The nightly MR has the
   nightly pipeline as its latest.

All five PHP components are audited, including `modules/aws` and
`modules/openai`, and those two come back clean. See the Dockerfile section
for why that result means less than it looks.

## The Dockerfile problem

`docker/Dockerfile.php` runs `composer install` for most components and
`composer update --ignore-platform-reqs` for `modules/aws` and `modules/openai`.

- **The audit and the image disagree.** `composer audit --locked` checked
  aws/aws-sdk-php 3.372.0 and openai-php/client v0.20.0. `composer update`
  ignores the lockfile and resolves again at build time. On 2026-10-06 that
  gives 3.399.1 and v0.21.0. G8 passed code that is not what ships.
- **Builds are not repeatable.** The same commit built on two days produces two
  different images, so a rollback rebuild is not the image you rolled back to.
- **A bad release goes straight to the image.** A vulnerable or compromised new
  version is pulled in with no merge request, no review and no gate.
- **`--ignore-platform-reqs` hides incompatibility.** It skips the check that
  the resolved versions support the image's PHP version and extensions. The
  failure moves from build time to run time.

G8 check 7 prints this as a warning. It does not block.

## Remediation

### 1. Install npm on the runner

On the runner host (Debian/Ubuntu shown):

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# Check it the way a job will see it, as the runner's user:
sudo -u gitlab-runner -H bash -lc 'node -v && npm -v'
```

- Install system-wide. `nvm` installs per user and loads from an interactive
  shell profile, which runner jobs do not read.
- `npm audit` calls the registry, so the runner needs to reach
  `registry.npmjs.org` or your internal mirror.
- Update `RUNNER_TOOLS` and the comment in `ci/rules.yml` so the description
  matches the host. `fix-1-install-npm.sh` makes that edit, which is also what
  puts npm on the simulated runner.

After this, `npm-audit` writes a report: 0 high or critical, 1 moderate
(esbuild, a dev dependency). G8 reports the moderate and passes the check.

### 2. Clear the fixtures in `log_redaction_security.php`

Replace the hardcoded tokens with ones built at run time:

```php
'github' => 'ghp_' . str_repeat('a1B2', 9),
```

The test still proves the redactor works, and nothing secret-shaped is
committed. Then regenerate the counts and commit both files:

```bash
ci/scripts/docs-counts.sh --write
```

The table in `docs/cicd.md` goes from 3 open findings to 0. G8 check 6 compares
that table with the scan, so clearing the fixtures without updating the doc
fails the gate too.

This is better than allowlisting `tests/`. A path allowlist excuses every
future secret in that directory. If your pipeline scans git history
(`gitleaks git`) the old commit still contains the tokens, so you would also
need a baseline or a scan range that starts after the fix. This example scans
the working tree (`gitleaks dir`).

### 3. Record the advisories in `dependency-exceptions.json`

The file's `policy` block sets the limits, and G8 enforces them:

| Limit | Value |
|---|---|
| Active exceptions | at most 5 |
| Lifetime, critical | at most 14 days |
| Lifetime, high | at most 30 days |
| Reason | at least 30 characters |
| Required fields | advisory, package, path, severity, reason, owner, ticket, added, expires |

`fix-3-record-exceptions.sh` writes three entries dated from today, each at its
maximum lifetime, then updates `docs/cicd.md` (active exceptions 0 to 3). One
entry:

```json
{
  "advisory": "CVE-2021-32708",
  "package": "league/flysystem",
  "path": "modules/backup",
  "severity": "critical",
  "reason": "Fixed in 1.1.4. Backup paths come from operator config, not user input. Upgrade is in review.",
  "owner": "platform-team",
  "ticket": "PULSE-1422",
  "added": "2026-10-06",
  "expires": "2026-10-20"
}
```

An exception matches on path, package and advisory together, so excepting
Flysystem in `modules/backup` does not excuse it anywhere else. When it
expires the advisory blocks again.

All three advisories have a fixed release. The exceptions buy time for the
upgrade and its testing. They are not the fix. The reasons, owners and tickets
in the script are placeholders.

## Other solutions

- **Upgrade instead of excepting.** Flysystem 1.1.3 to 1.1.4 and Guzzle 7.15.1
  to 7.15.2 are patch bumps. If they can land today, they need no exception.
  Only dompdf needs real testing.
- **Run npm in a container instead of installing it.** The runner already has
  docker: `docker run --rm -v "$PWD":/app -w /app node:22-alpine npm audit --json --package-lock-only`.
  The Node version is then pinned in the repo, not on the host.
- **Build the image from the lockfiles.** `fix-4-build-from-lockfiles.sh`
  changes the two `composer update` lines to `composer install` and drops
  `--ignore-platform-reqs`.
- **Keep the SDKs fresh through merge requests.** A scheduled job (Renovate, or
  a nightly `composer update` that opens an MR) changes the lockfile, which
  triggers `composer-audit` and G8 before anything ships.
- **Scan the built image.** A later phase can run an image scanner so what
  ships is checked directly, whatever the Dockerfile did.
- **Fail early when a tool is missing.** A first job that compares
  `RUNNER_TOOLS` with what each job needs turns a 2 a.m. exit 127 into a clear
  message on the merge request that added the job.
