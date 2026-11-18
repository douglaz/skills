{ pkgs, lib, ... }:

let
  # CDP port inside the guest. Chromium binds it to the guest's loopback only;
  # the host reaches it through `ssh -L`, never through a QEMU port forward.
  cdpPort = 9222;

  # The host's public key. `browser-vm up` writes this file next to the flake
  # before building; the private half never enters the Nix store.
  authorizedKey = lib.removeSuffix "\n" (builtins.readFile ./authorized_key.pub);

  # NopeCHA CAPTCHA solver, regular build, pinned by hash. The "automation"
  # build only reads its API key from the manifest, which would put the key in
  # the Nix store; this one takes it at runtime (`browser-vm nopecha-key`).
  # It lives in the Nix store, so the guest cannot modify it.
  nopechaZip = pkgs.fetchurl {
    url = "https://github.com/NopeCHALLC/nopecha-extension/releases/download/0.6.1/chromium.zip";
    sha256 = "cfbbe7b3a3d28939abe92fd7b194ae89e39aad6a286d1df89b9eed9ea2bf612e";
  };
  nopecha = pkgs.runCommand "nopecha-extension-0.6.1" { nativeBuildInputs = [ pkgs.unzip ]; } ''
    mkdir -p $out
    unzip -q ${nopechaZip} -d $out
  '';

  # Destinations the guest must never open a connection to: the host itself
  # (10.0.2.2 is the host's loopback under QEMU user networking), private
  # LANs, the CGNAT range that overlay networks such as Tailscale use, and
  # link-local.
  blockedNets = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "100.64.0.0/10"
    "169.254.0.0/16"
  ];

  profileDir = "/home/browser/profile";
  resetMarker = "/home/browser/reset-profile";
in
{
  system.stateVersion = "26.05";
  networking.hostName = "browser-vm";

  # ---- VM shape -----------------------------------------------------------
  # The SSH port forward is not declared here: `browser-vm up` passes it in
  # QEMU_NET_OPTS, bound to the host's 127.0.0.1.
  virtualisation = {
    memorySize = 4096;
    cores = 4;
    diskSize = 8192;
    graphics = false;

    # Do not mount the host's /nix/store into the guest: build an image that
    # holds only this system's closure.
    useNixStoreImage = true;
    mountHostNixStore = false;
    writableStore = false;

    # qemu-vm.nix shares two writable host directories (xchg, shared) with the
    # guest by default. Nothing here uses them, and a browser that can write to
    # the host's disk is not isolated from it.
    sharedDirectories = lib.mkForce { };
  };

  # ---- Network isolation --------------------------------------------------
  networking.enableIPv6 = false;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    extraCommands = ''
      iptables -N vm-egress 2>/dev/null || iptables -F vm-egress
      iptables -D OUTPUT -j vm-egress 2>/dev/null || true
      iptables -A vm-egress -o lo -j RETURN
      iptables -A vm-egress -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
      iptables -A vm-egress -d 10.0.2.3 -p udp --dport 53 -j RETURN
      iptables -A vm-egress -d 10.0.2.3 -p tcp --dport 53 -j RETURN
      ${lib.concatMapStringsSep "\n" (net: "iptables -A vm-egress -d ${net} -j REJECT") blockedNets}
      iptables -I OUTPUT -j vm-egress
    '';
    extraStopCommands = ''
      iptables -D OUTPUT -j vm-egress 2>/dev/null || true
    '';
  };

  # ---- Access: one unprivileged user, key only, no sudo, no root login ----
  users.mutableUsers = false;
  # Deliberate: no root or wheel login. The VM is disposable; change it by rebuilding.
  users.allowNoPasswordLogin = true;
  users.users.browser = {
    isNormalUser = true;
    extraGroups = [ "systemd-journal" ];
    openssh.authorizedKeys.keys = [ authorizedKey ];
  };
  security.sudo.enable = false;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "browser" ];
    };
  };

  # ---- The browser --------------------------------------------------------
  fonts.packages = [
    pkgs.dejavu_fonts
    pkgs.liberation_ttf
    pkgs.noto-fonts
  ];

  systemd.services.chromium-cdp = {
    description = "Headed Chromium under Xvfb with CDP on 127.0.0.1:${toString cdpPort}";
    wantedBy = [ "multi-user.target" ];
    # The browser must never run unfiltered: if the firewall unit fails (one bad
    # iptables line aborts its script before the egress chain is hooked in),
    # this unit does not start.
    requires = [ "firewall.service" ];
    after = [
      "network-online.target"
      "firewall.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      User = "browser";
      WorkingDirectory = "/home/browser";
      Restart = "always";
      RestartSec = 3;
      MemoryMax = "3G";
      # `browser-vm reset-profile` drops the marker and kills the browser;
      # the profile is wiped here, while nothing has it open.
      ExecStartPre = pkgs.writeShellScript "chromium-cdp-pre" ''
        if [ -e ${resetMarker} ]; then
          ${pkgs.coreutils}/bin/rm -rf ${profileDir}
          ${pkgs.coreutils}/bin/rm -f ${resetMarker}
        fi
      '';
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.xvfb-run}/bin/xvfb-run -a -s '-screen 0 1366x900x24'"
        "${pkgs.chromium}/bin/chromium"
        "--user-data-dir=${profileDir}"
        "--remote-debugging-address=127.0.0.1"
        "--remote-debugging-port=${toString cdpPort}"
        "--remote-allow-origins=*"
        "--load-extension=${nopecha}"
        "--disable-features=DisableLoadExtensionCommandLineSwitch"
        "--no-first-run"
        "--no-default-browser-check"
        "--window-size=1366,900"
        "about:blank"
      ];
    };
  };

  environment.systemPackages = [ pkgs.chromium ];

  documentation.enable = false;
  services.getty.autologinUser = lib.mkForce null;
}
