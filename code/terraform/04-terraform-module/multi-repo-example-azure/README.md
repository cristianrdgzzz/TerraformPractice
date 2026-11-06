Multi-Repo Example — Modules & Live Repos, Versioning and Module Sources

This folder demonstrates a multi-repository approach: keep reusable
infrastructure code (modules) separate from the live, environment-specific
configuration (live). This README explains module versioning, supported
module source formats, recommended Git workflows, private repo usage, and a
solution for a common Windows `git` error when Terraform downloads modules.

## Concepts: `modules` vs `live`

- `modules`: Reusable building blocks (blueprints). These should be
  stored in a dedicated repository (e.g. `acme-modules`) and versioned.
- `live`: Environment-specific code that composes modules into running
  infrastructure (the houses built from blueprints). Keep each live
  configuration in its own repository (e.g. `acme-live-prod`,
  `acme-live-stage`).

Why separate repositories?
- Clear separation of concerns, smaller diffs and focused reviews.
- Independent lifecycles: modules can be released and consumed by many
  live repos without coupling their commits.
- Easier to apply different access controls (e.g. separate accounts/teams).

## Module source formats supported by Terraform

Terraform supports several source formats for modules (examples):
- Git (HTTPS): `git::https://github.com/OWNER/REPO.git//path/to/module?ref=v1.2.3`
- Git (SSH): `git::git@github.com:OWNER/REPO.git//path/to/module?ref=v1.2.3`
- Mercurial: `hg::https://hg.example.com/repo//path?ref=rev`
- HTTP archive: `https://example.com/modules.tar.gz`
- Registry and local paths: `registry.terraform.io/...` or `../modules/foo`

Notes:
- Add `//<subdir>` to select a subdirectory within the repository.
- Add `?ref=<version>` to pin the module to a Git tag/branch/commit.

## Versioning modules (recommended)

- Use Git tags as version numbers for modules. Tags are stable pointers
  to commits and are human-readable.
- Prefer Semantic Versioning: `MAJOR.MINOR.PATCH` (e.g., `1.0.4`).
  - Increment `MAJOR` for incompatible API changes.
  - Increment `MINOR` for new backwards-compatible functionality.
  - Increment `PATCH` for backwards-compatible bug fixes.

Why tags instead of branches?
- Branch names are moving targets ("latest" changes every commit).
- Tags are stable; `?ref=v1.2.3` always refers to the same commit.

Example Git workflow (create modules repo and publish a tag):

```bash
cd modules
git init
git add .
git commit -m "Initial commit of modules repo"
git remote add origin "(URL OF REMOTE GIT REPO)"
git push origin main
git tag -a "v0.0.1" -m "First release of webserver module"
git push --follow-tags
```

## Using private Git repositories for modules

If a module lives in a private Git repository, Terraform needs to authenticate
to fetch it. Recommended approach: SSH auth. Advantages:
- No credentials in code.
- Each developer or automation agent uses their SSH key.

Example module source (SSH, pinned to a tag):

```
module "webserver_cluster" {
  source = "git@github.com:acme/modules.git//services/webserver-cluster?ref=v0.1.2"
}
```

Quick check: verify you can clone the base URL before using it in Terraform:

```bash
git clone git@github.com:acme/modules.git
```

If the clone succeeds, Terraform should be able to download the module.

## Troubleshooting: "Filename too long" when Terraform downloads a Git module (Windows)

Error example (when running `terraform init`):

```
fatal: cannot write keep file '.../modules/webserver_cluster/.git/objects/pack/pack-...keep': Filename too long
fatal: fetch-pack: invalid index-pack output
```

This error commonly appears on Windows because of path length limits. Here
are recommended solutions, ordered from simplest to most robust:

1) Use a shorter working directory path

   - Move your repository higher in the filesystem (e.g. `C:\repos\...`) so
     the total path length is reduced.

2) Enable long paths in Git for Windows

   - Ensure you have a recent Git for Windows installed (2.10+).
   - Run (requires admin for system config):

     ```powershell
     git config --system core.longpaths true
     ```

   - Alternatively set per-user (no admin):

     ```powershell
     git config --global core.longpaths true
     ```

3) Enable long paths in Windows (if needed)

   - Windows 10 and later support long paths if the policy is enabled.
   - To enable (requires admin), run PowerShell as Administrator and:

     ```powershell
     New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name LongPathsEnabled -Value 1 -PropertyType DWORD -Force
     ```

   - Reboot may be required. Use this only if permitted by your IT/security
     policies.

4) Use a shallower clone or download method (workaround)

   - If the repo contains very long filenames, consider packaging the
     specific module subdirectory as a tarball and hosting it on an HTTP
     server or using the Terraform Registry.

5) As a last resort, shorten repository directory names or avoid nested
   folders with long names in the module path.

After fixing the Git/Windows configuration, re-run `terraform init` and the
module should download successfully.

## Practical advice for the code in this repository

- Avoid pointing `live` modules at the same Git repository that contains
  `live` code. Instead, publish your modules in their own repository and
  reference them with `source = "git::..."` and `?ref=vX.Y.Z`.
- During development you can point `source` to a local path (`../modules/...`)
  to iterate quickly, but switch to tagged Git refs for stable deployments.

## Example: module source lines

- SSH + subdir + tag (recommended for private repos):
  `git::git@github.com:acme/modules.git//services/webserver-cluster?ref=v1.2.3`
- HTTPS + subdir + tag (public repos):
  `git::https://github.com/acme/modules.git//services/webserver-cluster?ref=v1.2.3`

## Closing notes

Maintaining stable module sources and using semantic tags reduces deployment
risk and makes rollbacks straightforward. If you want, I can:

- Convert the `multi-repo-example` wrappers to reference a separate `modules`
  repo (create example `git::` sources with tags), or
- Add `example.tfvars` to the live folders to document required variables.

Tell me which follow-up you want and I will prepare the changes (no
execution, only editing README/snippets).
