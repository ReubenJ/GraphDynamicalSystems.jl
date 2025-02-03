{
  inputs = {
    utils.url = "github:numtide/flake-utils";
    old-julia.url = "nixpkgs/5fd8536a9a5932d4ae8de52b7dc08d92041237fc";
  };
  outputs = { self, nixpkgs, utils, old-julia }: utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      julia1-10-2-pkgs = old-julia.legacyPackages.${system};
    in
    {
      devShell = pkgs.mkShell {
        buildInputs = [
          julia1-10-2-pkgs.julia-bin
        ];
      };
    }
  );
}
