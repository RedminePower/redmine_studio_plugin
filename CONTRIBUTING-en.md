# Contributing

[日本語](CONTRIBUTING.md)

## Branches

master is the version delivered to users. Following the README, `git clone` installs master, so anything merged into master reaches users as is.

- Development happens on a development branch per version, `v<version>_dev` (e.g. `v2.3.0_dev`). The current development branch is the `v*_dev` branch with the highest version number (if you cannot find one, please ask in an issue)
- Create your working branch from `v<version>_dev` and target your pull request at `v<version>_dev`. GitHub sets the base of a new pull request to master, so change it to `v<version>_dev`
- master is updated from `v<version>_dev` only when releasing. The only exception is reverting a released version (the revert pull request targets master)

## Releasing

1. When the release is being finalized, create the development branch for the next version from `v<version>_dev`. From then on, pull requests for new work target the next version, and only fixes for this version go into `v<version>_dev`
2. Bump the version in `init.rb` (2 places) on a working branch and merge it into `v<version>_dev` with a pull request
3. Open a draft pull request from `v<version>_dev` to master. Keep it as a draft until the release is decided
4. When the release is decided, mark it ready and merge it with a merge commit (not squash or rebase). Then publish the Release (tag `v<version>`)
5. Merge master into the other development branches (such as the next version created in step 1) with a pull request (do not rebase)
