{
  containers,
  lib,
  ...
}: let
  inherit (lib.alias) radii;
  inherit (lib.attrsets) attrValues;
  inherit (lib.extra.sigil) getULA;
in let
  allowedContainers =
    (with containers.intra; [
      b6cab864-64cc-454d-8647-30348af279da # automation/connections
      a4205b50-197a-40c8-8057-fe1394630e91 # automation/n8n
      fe616e36-c9d0-4ba9-8938-436e75ef0dc0 # sharing/runners
      fecc0d40-eb4e-43d4-b0ef-c0627fcce582 # sharing/music
    ])
    |> map getULA;

  allowedHosts =
    # ────────────────────────────────────────────────────────────────────────
    # NOTE: Allow requests from every host of the site (radii's overlay),
    #       devices included.
    # ────────────────────────────────────────────────────────────────────────
    attrValues radii.site |> map (h: h.hostAddress);
in
  allowedContainers ++ allowedHosts
