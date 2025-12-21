{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      shell = { pkgs, ... }:
        with pkgs;
        mkShell rec {
          buildInputs = [
            ansible
            rpi-imager
            zig
            zls
            libx11
            libxfixes
            libxrandr
            libxinerama
            libxi
            libxrender
            libxext
            libxcursor
            libGL
            # pkg-config
            # pkgsCross.aarch64-multiplatform.libGL
            # pkgsCross.aarch64-multiplatform.libdrm
            # pkgsCross.aarch64-multiplatform.libgbm
            # pkgsCross.aarch64-multiplatform.pkg-config
          ];
          LD_LIBRARY_PATH = "${lib.makeLibraryPath buildInputs}";
          PKG_CONFIG_ALLOW_CROSS = 1;
        };
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          devShells.default = shell { inherit pkgs system; };
        });
}
