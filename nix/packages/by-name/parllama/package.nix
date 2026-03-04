{
  lib,
  python3Packages,
  fetchFromGitHub,
  fetchPypi,
  makeDesktopItem,
  ...
}: let
  pname = "parllama";
  version = "0.8.4";

  clipman = let
    pname = "clipman";
    version = "3.3.3";
  in
    python3Packages.buildPythonPackage {
      inherit pname version;

      src = fetchPypi {
        inherit pname version;
        hash = "sha256-gDQdcY7z5TRAARZ+UBc7KUZRb4lwuRgDNdLeldV/QDw=";
      };

      pyproject = true;

      strictDeps = true;

      build-system = with python3Packages; [
        setuptools
        setuptools-scm
      ];

      dependencies = with python3Packages; [
        dbus-next
      ];
    };

  par-ai-core = let
    pname = "par_ai_core";
    version = "0.5.5";

    extraDependencies = {
      langchain-google-community = let
        pname = "langchain_google_community";
        version = "3.0.5";

        extraDependencies = {
          google-cloud-modelarmor = let
            pname = "google_cloud_modelarmor";
            version = "0.4.0";
          in
            python3Packages.buildPythonPackage {
              inherit pname version;

              src = fetchPypi {
                inherit pname version;
                hash = "sha256-bgeUHm7lTSjOOTPVDQmZ0t/jKz05tJp5HnsYAjfbAWY=";
              };

              pyproject = true;

              strictDeps = true;

              build-system = [python3Packages.setuptools];

              dependencies = with python3Packages; [
                google-api-core
                google-auth
                grpcio
                proto-plus
                protobuf
              ];
            };
        };
      in
        python3Packages.buildPythonPackage {
          inherit pname version;

          src = fetchPypi {
            inherit pname version;
            hash = "sha256-Y/v7MMmTcTdmLYjZ24BdqkVcYFGKv0rVCh9y3O83+hQ=";
          };

          pyproject = true;

          strictDeps = true;

          build-system = [python3Packages.hatchling];

          dependencies = with python3Packages; [
            langgraph
            langchain-core
            langchain
            langchain-community
            google-api-core
            google-api-python-client
            google-cloud-core
            grpcio
            extraDependencies.google-cloud-modelarmor
          ];
        };

      tavily-python = let
        pname = "tavily_python";
        version = "0.7.21";
      in
        python3Packages.buildPythonPackage {
          inherit pname version;

          src = fetchPypi {
            inherit pname version;
            hash = "sha256-iXvt+bHC+thgW+ZC5BfWx+wbeb9hmVY0d89pxDE/gko=";
          };

          pyproject = true;

          strictDeps = true;

          build-system = [python3Packages.setuptools];

          dependencies = with python3Packages; [
            requests
            tiktoken
            httpx
          ];
        };
    };
  in
    python3Packages.buildPythonPackage {
      inherit pname version;

      src = fetchPypi {
        inherit pname version;
        hash = "sha256-TkwFDbgeJs2U88UCwgo/kMgzu2SD0gZq7W6C+lcB2IM=";
      };

      pyproject = true;

      strictDeps = true;

      build-system = [python3Packages.hatchling];

      dependencies = with python3Packages; [
        boto3
        botocore
        html2text
        langchain-anthropic
        langchain-aws
        langchain-community
        langchain-deepseek
        langchain-experimental
        extraDependencies.langchain-google-community
        langchain-google-genai
        langchain-groq
        langchain-mistralai
        langchain-ollama
        langchain-openai
        langchain-text-splitters
        langchain-xai
        langchain
        langgraph
        litellm
        markdownify
        nest-asyncio
        openai
        orjson
        playwright
        praw
        pydantic-core
        pydantic
        python-dotenv
        requests
        rich
        selenium
        strenum
        extraDependencies.tavily-python
        webdriver-manager
        youtube-transcript-api
      ];

      pythonRelaxDeps = [
        "boto3"
        "botocore"
        "selenium"
      ];
    };

  textual-fspicker = let
    pname = "textual_fspicker";
    version = "0.6.0";
  in
    python3Packages.buildPythonPackage {
      inherit pname version;

      src = fetchPypi {
        inherit pname version;
        hash = "sha256-DaDj81Al9yxbkFV9End8n2fGdEcLMmPL4sLeOPW3DDw=";
      };

      pyproject = true;

      strictDeps = true;

      build-system = [python3Packages.uv-build];

      dependencies = with python3Packages; [
        textual
      ];

      postPatch = ''
        substituteInPlace pyproject.toml \
          --replace-fail "uv_build>=0.8.11,<0.9.0" "uv-build==${python3Packages.uv-build.version}"
      '';
    };
in
  python3Packages.buildPythonApplication {
    inherit pname version;
    
    src = fetchPypi {
      inherit pname version;
      hash = "sha256-aEb9yu3mupui5rwQ8WlbQMTO4D1VAXl37QO3QaPEKMU=";
    };

    pyproject = true;

    strictDeps = true;

    build-system = [python3Packages.hatchling];

    dependencies = with python3Packages;
      [
        beautifulsoup4
        build
        cryptography
        docker
        google-genai
        httpx
        humanize
        langchain
        ollama
        orjson
        pydantic
        pydantic-core
        python-dotenv
        pytz
        requests
        rich
        rich-pixels
        semver
        textual

        urllib3
        xdg-base-dirs
      ]
      ++ [
        clipman
        par-ai-core
        textual-fspicker
      ];

    pythonRelaxDeps = [
      "humanize"
      "textual"
    ];

    pythonRemoveDeps = [
      "argparse"
    ];

    optional-dependencies = with python3Packages; {
      web = [
        textual-serve
      ];
    };

    pythonImportsCheck = [
      "parllama"
    ];

    desktopItem = makeDesktopItem {
      name = "PAR LLAMA";
      desktopName = "PAR LLAMA";
      exec = "parllama %U";
      comment = "TUI for Ollama and other LLM providers";
      categories = ["Utility" "Chat" "Network" "ConsoleOnly"];
    };

    meta = {
      description = "TUI for Ollama and other LLM providers";
      homepage = "https://github.com/paulrobello/parllama";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [alexandrutocar];
      mainProgram = "parllama";
    };
  }
