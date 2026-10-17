{
  lib,
  python3Packages,
  fetchFromGitHub,
  stress,
}:

python3Packages.buildPythonApplication {
  pname = "bc250-smu-oc";
  version = "0-unstable-2026-09-27";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "bc250-collective";
    repo = "bc250_smu_oc";
    rev = "327014d6515d7108b1144adfa7203b4cc2eefd0b";
    hash = "sha256-YKzdUiDJRoEubvms263DD6CfaZhj8S5kigOoIS+shfA=";
  };

  build-system = [ python3Packages.setuptools ];

  propagatedBuildInputs = [ stress ];

  meta = {
    description = "CPU overclocking tools for the AMD BC-250";
    homepage = "https://github.com/bc250-collective/bc250_smu_oc";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
