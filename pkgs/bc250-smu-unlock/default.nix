{
  lib,
  python3Packages,
  fetchFromGitHub,
}:

python3Packages.buildPythonApplication {
  pname = "bc250-smu-unlock";
  version = "0-unstable-2026-09-18";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "rw-r-r-0644";
    repo = "bc250-smu-unlock";
    rev = "f5886d015af9019a30bd402c35e011beded07b61";
    hash = "sha256-h6W/Cj4sO+bSmYhv1yoexW50tBBO0vmScbcViWM0ILM=";
  };

  build-system = [ python3Packages.setuptools ];

  # The script sets its own module path, so its runtime is this package and
  # the interpreter, which is all the initrd includes.
  dontWrapPythonPrograms = true;

  postInstall = ''
    install -Dm755 ${./bc250-smu-apply.py} "$out/bin/bc250-smu-apply"
    substituteInPlace "$out/bin/bc250-smu-apply" \
      --replace-fail '@PYTHON@' "${python3Packages.python.interpreter}" \
      --replace-fail '@SITE@' "$out/${python3Packages.python.sitePackages}" \
      --replace-fail '@HEX@' "$out/${python3Packages.python.sitePackages}/bc250_smu/patches.hex"
  '';

  pythonImportsCheck = [
    "bc250_smu"
    "patcher"
    "unlock"
  ];

  meta = {
    description = "Unlock the AMD BC-250 SMU and patch its firmware memory to report metrics for 8 cores";
    homepage = "https://github.com/rw-r-r-0644/bc250-smu-unlock";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "bc250-smu-apply";
  };
}
