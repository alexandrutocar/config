final: super: {
  # vscodium = super.vscodium.overrideAttrs (pkgSuper: {
  #   postInstall = let
  #     inherit (super.lib.meta) getExe;
  #     inherit (super) xxd;
  #   in
  #     pkgSuper.postInstall or ""
  #     + ''
  #       app="$out/lib/vscode/resources/app"
  #       css="$app/out/vs/workbench/workbench.desktop.main.css"

  #       cat ${./patch/workbench.desktop.main.css} >> "$css"

  #       checksum=$(sha256sum "$css" | cut -d' ' -f1 | ${getExe xxd} -r -p | base64 | tr -d '=')
  #       jq --arg c "$checksum" '.checksums."vs/workbench/workbench.desktop.main.css" = $c' "$app/product.json" > "$app/product.json.tmp"
  #       mv "$app/product.json.tmp" "$app/product.json"
  #     '';
  # });
}
