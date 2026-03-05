# Changelog

## [0.2.0](https://github.com/gh-extensions/gh-worktree/compare/v0.1.0...v0.2.0) (2026-03-05)


### Features

* align project structure with gh-ai conventions ([113e47b](https://github.com/gh-extensions/gh-worktree/commit/113e47bf425faa5565f2493f83ebf4c5c04860cd))
* initial implementation of gh-worktree extension ([a5323c1](https://github.com/gh-extensions/gh-worktree/commit/a5323c1426b209f5085e2da7a9f19d7bfcd0a78f))
* make worktree base directory configurable ([b03d3d5](https://github.com/gh-extensions/gh-worktree/commit/b03d3d53886d413b63f6dbcf0adeacde2b90ec40))
* use gum spin --show-error for worktree creation ([55f8434](https://github.com/gh-extensions/gh-worktree/commit/55f84342199dfe9bf125b8310fff334d20278b6f))


### Bug Fixes

* add gum spin to default branch fetch, drop --show-error with || true ([d0ead16](https://github.com/gh-extensions/gh-worktree/commit/d0ead16362aea4b1536feb3b311d6ce02fd249e6))
* address all deep review findings ([c88133f](https://github.com/gh-extensions/gh-worktree/commit/c88133f459c8b28a0e44ff4aac3311467535dd46))
* address deep review findings ([1d447c5](https://github.com/gh-extensions/gh-worktree/commit/1d447c5c3483f9058b86d398b7d9010d8e32cb2d))
* address tech debt and docs from second deep review ([77d79c6](https://github.com/gh-extensions/gh-worktree/commit/77d79c63562730d54a6f992ee11cd23915be473c))
* address tech debt and inconsistencies from deep review ([2c1e919](https://github.com/gh-extensions/gh-worktree/commit/2c1e919eb7b39ae61bb5d078ae7b912996d31ad9))
* call _worktree_create directly instead of via gum spin ([0e60459](https://github.com/gh-extensions/gh-worktree/commit/0e6045997504bad6d2ed2c7b24d2695c6cd575ea))
* expand worktree_path at trap-set time to avoid scope loss ([95f82e6](https://github.com/gh-extensions/gh-worktree/commit/95f82e661dd25dc78c7fe5d6b7d26063429b12ad))
* guard symbolic-ref with || true and add Stdout doc to base_dir ([edc6080](https://github.com/gh-extensions/gh-worktree/commit/edc6080e146110d989a5b44b1b6b7c5664da665c))


### Reverts

* restore shebangs in sourced scripts ([1e56e3a](https://github.com/gh-extensions/gh-worktree/commit/1e56e3a374fe10ef1284746c1589d41ffe6f9b74))
