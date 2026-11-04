{
  description = "gh-worktree development shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # The tools that the extension calls, in the PATH of its wrapper
        runtimeInputs = with pkgs; [
          bash
          gh
          git
          gum
          jq
        ];
      in
      {
        # The extension as gh reads it: a directory named after it with the executable in it. home-manager's
        # programs.gh.extensions links the bin/ of this package as that directory. The script finds its scripts next to
        # itself, so the repository is installed whole in libexec and the wrapper in bin/ only sets the PATH
        packages.default = pkgs.stdenvNoCC.mkDerivation {
          pname = "gh-worktree";
          version = nixpkgs.lib.fileContents ./version.txt;
          src = ./.;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/libexec/gh-worktree $out/bin
            cp -r . $out/libexec/gh-worktree
            rm -rf $out/libexec/gh-worktree/{tests,flake.nix,flake.lock,.envrc,.gitignore}
            chmod +x $out/libexec/gh-worktree/gh-worktree

            makeWrapper $out/libexec/gh-worktree/gh-worktree $out/bin/gh-worktree \
              --prefix PATH : ${pkgs.lib.makeBinPath runtimeInputs}

            runHook postInstall
          '';

          meta = {
            description = "Spin up isolated git worktrees for pull requests, issues, and workflow runs";
            homepage = "https://github.com/gh-extensions/gh-worktree";
            license = pkgs.lib.licenses.mit;
            mainProgram = "gh-worktree";
          };
        };

        devShells.default = pkgs.mkShell {
          name = "gh-worktree";
          packages =
            runtimeInputs
            ++ (with pkgs; [
              bats
              shellcheck
            ]);
        };
      }
    );
}
