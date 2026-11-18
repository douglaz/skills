{
  description = "Isolated NixOS QEMU VM that runs Chromium for browser automation over CDP";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.browser-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
          ./configuration.nix
        ];
      };

      packages.${system}.default = self.nixosConfigurations.browser-vm.config.system.build.vm;
    };
}
