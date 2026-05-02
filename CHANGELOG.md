# Changelog

## [0.7.0](https://github.com/gh-extensions/gh-worktree/compare/v0.6.1...v0.7.0) (2026-05-02)


### Features

* replace --keep flag with explicit rm subcommand for worktree cleanup ([5cceee7](https://github.com/gh-extensions/gh-worktree/commit/5cceee79aa06926c3e68c71447dfa3b35b1be613))


### Bug Fixes

* **worktree:** run git commands against repo root instead of cwd ([e582639](https://github.com/gh-extensions/gh-worktree/commit/e582639545a8c0ab00cc62c0ce0322940165fad8))

## [0.6.1](https://github.com/gh-extensions/gh-worktree/compare/v0.6.0...v0.6.1) (2026-04-16)


### Bug Fixes

* add postCreateCommand to restore nix volume permissions ([8408fb2](https://github.com/gh-extensions/gh-worktree/commit/8408fb2609eee2a9775275cf22b61a69d81f17c2))

## [0.6.0](https://github.com/gh-extensions/gh-worktree/compare/v0.5.0...v0.6.0) (2026-03-19)


### Features

* export GH_CLAUDE_DEFAULT_SESSION_ID for persistent worktree sessions ([943d288](https://github.com/gh-extensions/gh-worktree/commit/943d288b593bdddca19f36f9d0a1e347b1f10e01))

## [0.5.0](https://github.com/gh-extensions/gh-worktree/compare/v0.4.1...v0.5.0) (2026-03-18)


### Features

* make gum an optional dependency ([1a76bcd](https://github.com/gh-extensions/gh-worktree/commit/1a76bcd2b249e0d187e85fef055241902ecfbd23))


### Reverts

* make gum a required dependency again ([ed070fe](https://github.com/gh-extensions/gh-worktree/commit/ed070fe1e75dfdf4e3fecab10f7bc9f14c450805))

## [0.4.1](https://github.com/gh-extensions/gh-worktree/compare/v0.4.0...v0.4.1) (2026-03-18)


### Bug Fixes

* suppress duplicate auto-stash message when removing dirty worktree ([5498d90](https://github.com/gh-extensions/gh-worktree/commit/5498d90f94234508220f4634315e2070d8475056))

## [0.4.0](https://github.com/gh-extensions/gh-worktree/compare/v0.3.2...v0.4.0) (2026-03-08)


### Features

* add zsh plugin entry point for plugin manager support ([56c14ac](https://github.com/gh-extensions/gh-worktree/commit/56c14ac1226dbc5e442e69c7b853ff3d4710a175))
* bind enter/alt-enter to tmux session/window in gh_fzf extras ([57ac0ce](https://github.com/gh-extensions/gh-worktree/commit/57ac0ce49794da5c89837f96e5a6285c47e0ebf5))


### Bug Fixes

* replace alt-W with alt-t for tmux window bindings ([e1abd5f](https://github.com/gh-extensions/gh-worktree/commit/e1abd5f0ccb2b9317c6462a1f24a34a5bfb2c5cc))
* replace alt-W/alt-S with alt-w/alt-enter for tmux bindings ([54ac5ce](https://github.com/gh-extensions/gh-worktree/commit/54ac5cef2e9042b147f62facf74df403a1316335))

## [0.3.2](https://github.com/gh-extensions/gh-worktree/compare/v0.3.1...v0.3.2) (2026-03-08)


### Bug Fixes

* add +abort and use execute-silent for alt-S in gh_fzf.sh ([2420c1d](https://github.com/gh-extensions/gh-worktree/commit/2420c1d59df2deae0e50cc232e916ea16a5ab271))
* serialize GH_FZF_*_OPTS with printf %q for eval-safe format ([a0f0ab1](https://github.com/gh-extensions/gh-worktree/commit/a0f0ab13bc4bd7779d30edf86ac9f98f2d19b848))

## [0.3.1](https://github.com/gh-extensions/gh-worktree/compare/v0.3.0...v0.3.1) (2026-03-06)


### Bug Fixes

* resolve gh_tmux.sh path as absolute in both bash and zsh ([b3cc744](https://github.com/gh-extensions/gh-worktree/commit/b3cc744f04c0330380b6748418740f2aaba892b7))

## [0.3.0](https://github.com/gh-extensions/gh-worktree/compare/v0.2.0...v0.3.0) (2026-03-06)


### Features

* add --keep flag to skip automatic worktree cleanup ([f6503a0](https://github.com/gh-extensions/gh-worktree/commit/f6503a0dbbc52e8bb8c995ac00a73eb9de99347e))
* add gh_tmux.sh helper and expand gh-fzf bindings ([7eb410a](https://github.com/gh-extensions/gh-worktree/commit/7eb410a88d226e06de1dc6c61df8a46a3eb43e3b))
* add gh-fzf extras binding and document integrations ([3ff440f](https://github.com/gh-extensions/gh-worktree/commit/3ff440fea4720d4cfc9d52f6b1297114fd472355))


### Bug Fixes

* use execute-silent + detach + switch-client to avoid TTY error ([77e0047](https://github.com/gh-extensions/gh-worktree/commit/77e0047514152b07b12fcc6888f6aeb387b64afc))

## [0.2.0](https://github.com/gh-extensions/gh-worktree/compare/v0.1.0...v0.2.0) (2026-03-05)


### Features

* core worktree utility functions ([a90b5c0](https://github.com/gh-extensions/gh-worktree/commit/a90b5c0e344d7fd379061f534bbe418d8b887d63))
* main entry point with dependency checks and dispatch ([5a153fe](https://github.com/gh-extensions/gh-worktree/commit/5a153fed7e0834c4a5b8e684cf192d71a22f8ac6))
* pr, issue, and run subcommand modules ([d00206f](https://github.com/gh-extensions/gh-worktree/commit/d00206f75193112f1fb5c36707a1a4bb97ef979b))


### Bug Fixes

* silence git fetch/worktree noise, surface errors through gum log ([c20e99b](https://github.com/gh-extensions/gh-worktree/commit/c20e99b3a8c34b521f4324282114943f992d48e9))
* warn when fast-forward fetch fails instead of silencing it ([6e1ad6b](https://github.com/gh-extensions/gh-worktree/commit/6e1ad6b9ec7190050cc6e8ccc9de33138cc88052))
