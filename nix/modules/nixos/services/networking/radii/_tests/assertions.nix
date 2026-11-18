# RADII: HOST ASSERTIONS
# ----------------------
# What radii refuses on the host that runs it, checked at evaluation: no
# machine boots. site-table.nix checks the table itself; this checks the
# host around it. Covers:
#   - a complete hub and a complete spoke raise nothing
#   - systemd-networkd not enabled (radii's tunnels would silently not exist)
#   - nftables not enabled
#   - no private key
#   - a host missing from the site table is told so by radii, not by an
#     evaluation error from somewhere inside the module
#   - a hub that leaves one of its tunnels unmanaged
#   - watchdog.staleAfter below what a working tunnel's handshake reaches
{
  pkgs,
  lib,
}: let
  inherit (lib.lists) any concatMap filter optional;
  inherit (lib.modules) mkForce;
  inherit (lib.strings) concatMapStringsSep hasInfix hasPrefix;

  # Public keys only: nothing here is brought up.
  site = {
    hub = {
      id = 1;
      hostAddress = "fd00:a::1";
      prefix = "fd00:a::/48";
      publicKey = "Y/QOeo3Poo4IvqGukMVYB851mrEmOHcO10TNcYGOUkc=";
      availableNetworks = ["::/0"];
      endpoints = ["2001:db8:1::1"];
      basePort = 51820;
      openPorts = [51822];
    };

    spoke = {
      id = 2;
      hostAddress = "fd00:b::2";
      prefix = "fd00:b::/48";
      publicKey = "T1zIzKlWBWSzXTkcTaYbd7qfYoPPNwd4R9m0OvQ2RS8=";
      availableNetworks = ["::/0"];
    };
  };

  # A NixOS evaluation of one host, with the same `lib` hosts get.
  evaluate = modules:
    import (pkgs.path + "/nixos/lib/eval-config.nix") {
      inherit lib;
      system = null;
      modules = [../default.nix {nixpkgs.pkgs = pkgs;}] ++ modules;
    };

  # Radii's failed assertions on that host, as their messages. Others (a
  # host without file systems fails several) are not this check's concern.
  failures = modules:
    map (assertion: assertion.message)
    (filter (assertion: !assertion.assertion && hasPrefix "radii:" assertion.message)
      (evaluate modules).config.assertions);

  # A host as radii needs it, named as in the site table.
  host = name: {
    networking = {
      hostName = name;
      useNetworkd = true;
      nftables.enable = true;
    };

    services.radii = {
      enable = true;
      settings.site = site;
      privateKey = "encrypted for the host, were this one real";
    };
  };

  # Each case: the host's modules, and text radii's message must contain
  # (null: no message at all).
  cases = [
    {
      name = "a complete hub";
      modules = [(host "hub")];
      expect = null;
    }
    {
      name = "a complete spoke";
      modules = [(host "spoke")];
      expect = null;
    }
    {
      name = "systemd-networkd not enabled";
      modules = [
        (host "spoke")
        {
          networking.useNetworkd = mkForce false;
          systemd.network.enable = mkForce false;
        }
      ];
      expect = "systemd.network.enable is not set";
    }
    {
      name = "nftables not enabled";
      modules = [(host "spoke") {networking.nftables.enable = mkForce false;}];
      expect = "networking.nftables.enable is not set";
    }
    {
      name = "no private key";
      modules = [(host "spoke") {services.radii.privateKey = mkForce null;}];
      expect = "services.radii.privateKey is not set";
    }
    {
      name = "a host missing from the site table";
      modules = [(host "stranger")];
      expect = "stranger is not in the site table";
    }
    # Not through ActivationPolicy: a hub's units already define it, so a
    # second value is a conflict before radii's assertion is asked.
    {
      name = "a hub leaving a tunnel unmanaged";
      modules = [
        (host "hub")
        {systemd.network.networks."40-rd-spoke".linkConfig.Unmanaged = "yes";}
      ];
      expect = "hubs keep their tunnels up";
    }
  ];

  wrongCases = concatMap (case: let
    found = failures case.modules;
    right =
      if case.expect == null
      then found == []
      else any (hasInfix case.expect) found;
  in
    optional (!right) "${case.name}: expected ${
      if case.expect == null
      then "no message"
      else "a message with \"${case.expect}\""
    }, got ${builtins.toJSON found}")
  cases;

  # STALE THRESHOLD
  # ---------------
  # A working tunnel's handshake gets up to about 150 seconds old before
  # WireGuard renews it, so a lower threshold would move working tunnels
  # and withdraw devices that are there.
  staleAfter = (evaluate [(host "spoke")]).options.services.radii.watchdog.staleAfter.type;

  wrongThresholds =
    map (seconds: "watchdog.staleAfter refuses ${toString seconds}") (filter (seconds: !(staleAfter.check seconds)) [150 180 600])
    ++ map (seconds: "watchdog.staleAfter takes ${toString seconds}") (filter staleAfter.check [1 60 120]);

  problems = wrongCases ++ wrongThresholds;
in
  if problems != []
  then throw "radii: host assertions are wrong:\n${concatMapStringsSep "\n" (problem: "  ${problem}") problems}"
  else pkgs.runCommand "radii-assertions" {} "touch $out"
