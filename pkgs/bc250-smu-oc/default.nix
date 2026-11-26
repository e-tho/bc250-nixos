{
  lib,
  python3Packages,
  fetchFromGitHub,
  stress,
}:

python3Packages.buildPythonApplication {
  pname = "bc250-smu-oc";
  version = "0-unstable-2026-11-21";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "bc250-collective";
    repo = "bc250_smu_oc";
    rev = "17294cb495cf80bbd27254c711af4742c979d951";
    hash = "sha256-uPLd4emy9GCnwbz9Pn8e2YX0sHxbfKYBlJOO5nmDIfU=";
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
