{
  description = "JonesForth - a minimal FORTH for macOS AArch64";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "jonesforth";
          version = "0.1.0";

          src = ./.;

          buildPhase = ''
            ${pkgs.stdenv.cc}/bin/cc -o jonesforth jonesforth.S
          '';

          installPhase = ''
            mkdir -p $out/bin $out/share/jonesforth
            cp jonesforth $out/bin/
            cp jonesforth.f $out/share/jonesforth/

            # Create a wrapper script that loads jonesforth.f automatically
            cat > $out/bin/jonesforth-repl <<'WRAPPER'
            #!/bin/sh
            exec cat @out@/share/jonesforth/jonesforth.f - | @out@/bin/jonesforth "$@"
            WRAPPER
            chmod +x $out/bin/jonesforth-repl
            substituteInPlace $out/bin/jonesforth-repl \
              --replace-quiet '@out@' "$out"
          '';

          meta = with pkgs.lib; {
            description = "A minimal FORTH compiler and tutorial for macOS AArch64";
            homepage = "https://github.com/nornagon/jonesforth";
            license = licenses.publicDomain;
            platforms = platforms.darwin;
          };
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.default ];
        };
      });
}
