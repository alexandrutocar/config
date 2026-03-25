{
  lib,
  fetchFromGitHub,
  python3Packages,
  ...
}: let
  pname = "foxessprom";
  version = "2.1.0";
in
  python3Packages.buildPythonApplication {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "andrewjw";
      repo = "foxessprom";
      tag = "v${version}";
      hash = "sha256-+7YLOGb7msMhRLN8EAmxe5sCApsUHH8T6b8oofYbTtA=";
    };

    pyproject = true;

    __structuredAttrs = true;
    strictDeps = true;

    build-system = [python3Packages.setuptools];

    pythonRelaxDeps = true;

    pythonRemoveDeps = ["python-semantic-release" "pymodbus"];

    dependencies = with python3Packages; [
      requests
      paho-mqtt
      # pymodbus
      sentry-sdk
    ];

    nativeBuildInputs = with python3Packages; [
      pycodestyle
      coveralls
      twine
      types-requests
      mypy
      requests-mock
    ];

    nativeCheckInputs = with python3Packages; [
      pytestCheckHook
    ];

    # ────────────────────────────────────────────────────────────────────────
    # TODO: Try enabling tests - not tested yet.
    # ────────────────────────────────────────────────────────────────────────
    doCheck = false;

    meta = {
      description = "Prometheus exporter for Fox ESS Inverters (using the Fox Cloud API)";
      mainProgram = "foxessprom";
      license = lib.licenses.mit;
      platforms = with lib.platforms; linux ++ darwin ++ windows;
      maintainers = with lib.maintainers; [alexandrutocar];
    };
  }
