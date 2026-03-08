# Changelog

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
