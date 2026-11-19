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

  # Optional WireGuard tunnel. `browser-vm vpn set` keeps a config on the host,
  # and `browser-vm up` hands it to the guest as a systemd credential through
  # QEMU's fw_cfg, so it never enters the Nix store and only root in the guest
  # can read it. Without the credential none of this runs.
  vpnCredential = "browser-vm.wg";
  vpnMark = "51820";

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

  # ---- Optional WireGuard tunnel -------------------------------------------
  # Runs only when the host passed a WireGuard config (see vpnCredential). It
  # first closes all egress, then brings the tunnel up and opens exactly two
  # paths: anything through the tunnel, and the tunnel's own packets to its
  # endpoint. If any step fails the guest stays closed and the browser, which
  # requires this unit, does not start. The blocked ranges of vm-egress still
  # apply inside the tunnel; the one exception is the tunnel's DNS server.
  systemd.services.vm-vpn = {
    description = "WireGuard tunnel for all guest traffic (only when the host supplies a config)";
    wantedBy = [ "multi-user.target" ];
    requires = [ "firewall.service" ];
    partOf = [ "firewall.service" ];
    after = [
      "network-online.target"
      "firewall.service"
    ];
    wants = [ "network-online.target" ];
    before = [ "chromium-cdp.service" ];
    unitConfig.ConditionCredential = vpnCredential;
    path = [
      pkgs.iproute2
      pkgs.iptables
      pkgs.wireguard-tools
      pkgs.openresolv
      pkgs.gawk
      pkgs.gnugrep
      pkgs.coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      LoadCredential = "wg:${vpnCredential}";
    };
    # Nothing below may print a line of the config: the journal is readable by
    # the browser's user.
    script = ''
      set -eu
      conf=$CREDENTIALS_DIRECTORY/wg
      fail() { echo "vm-vpn: $1; the guest stays offline" >&2; exit 1; }

      iptables -N vm-vpn 2>/dev/null || true
      iptables -C OUTPUT -j vm-vpn 2>/dev/null || iptables -I OUTPUT 1 -j vm-vpn
      iptables -F vm-vpn
      iptables -A vm-vpn -o lo -j RETURN
      iptables -A vm-vpn -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
      iptables -A vm-vpn -j REJECT

      # The first IPv4 value of a key (the guest has no IPv6).
      value() {
        awk -F= -v k="$1" 'tolower($1) ~ "^[ \t]*" k "[ \t]*$" { sub(/^[^=]*=/, ""); gsub(/[ \t\r]/, ""); print }' "$conf" \
          | tr , '\n' | grep -m1 -E "$2" || true
      }
      ip4='([0-9]{1,3}\.){3}[0-9]{1,3}'
      addr=$(value address "^$ip4(/[0-9]{1,2})?$")
      dns=$(value dns "^$ip4$")
      endpoint=$(value endpoint "^$ip4:[0-9]{1,5}$")
      mtu=$(value mtu '^[0-9]{3,4}$')
      [ -n "$addr" ] || fail "the config has no IPv4 Address"
      [ -n "$dns" ] || fail "the config has no IPv4 DNS server"
      [ -n "$endpoint" ] || fail "the config's Endpoint must be an IPv4 address and port"

      ip link del wg0 2>/dev/null || true
      ip link add wg0 type wireguard
      grep -viE '^[[:space:]]*(address|dns|mtu|table|preup|postup|predown|postdown|saveconfig)[[:space:]]*=' "$conf" \
        | wg setconf wg0 /dev/stdin 2>/dev/null || fail "wg rejected the config"
      wg set wg0 fwmark ${vpnMark}
      ip -4 addr add "$addr" dev wg0
      ip link set dev wg0 mtu "''${mtu:-1420}" up

      # Everything not sent by WireGuard itself takes the tunnel, except what
      # the main table routes more specifically (the VM's own subnet, which
      # carries the host's SSH connection).
      ip -4 route replace default dev wg0 table ${vpnMark}
      ip -4 rule del not fwmark ${vpnMark} table ${vpnMark} 2>/dev/null || true
      ip -4 rule del table main suppress_prefixlength 0 2>/dev/null || true
      ip -4 rule add not fwmark ${vpnMark} table ${vpnMark}
      ip -4 rule add table main suppress_prefixlength 0
      printf 'nameserver %s\n' "$dns" | resolvconf -a wg0 -m 0 -x

      iptables -I vm-vpn 3 -o wg0 -d "$dns" -p udp --dport 53 -j ACCEPT
      iptables -I vm-vpn 4 -o wg0 -d "$dns" -p tcp --dport 53 -j ACCEPT
      iptables -I vm-vpn 5 -o wg0 -j RETURN
      iptables -I vm-vpn 6 -m mark --mark ${vpnMark} -d "''${endpoint%:*}" -p udp --dport "''${endpoint##*:}" -j RETURN
      echo "vm-vpn: tunnel up"
    '';
    # Stopping takes the tunnel down and leaves egress closed.
    preStop = ''
      resolvconf -d wg0 2>/dev/null || true
      ip link del wg0 2>/dev/null || true
    '';
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
    # this unit does not start. The same goes for the tunnel when one is
    # configured; with none, vm-vpn is skipped and counts as satisfied.
    requires = [
      "firewall.service"
      "vm-vpn.service"
    ];
    after = [
      "network-online.target"
      "firewall.service"
      "vm-vpn.service"
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
