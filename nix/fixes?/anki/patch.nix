_: super: {
  anki = super.anki.overrideAttrs (old: {
    builtInputs = old.buildInputs ++ [super.qt6.qtwebengine];
  });
}
