{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "cortile";
  version = "2.5.2";

  src = fetchFromGitHub {
    owner = "leukipp";
    repo = "cortile";
    rev = "v${version}";
    hash = "sha256-2/U7oQO2vOrmoPR+s9VMSWS+d/YqZ5Ic0ieSxSA6SP4=";
  };

  vendorHash = "sha256-VlIPsUogiCQeWWrFsueB6COa91CWIGx3hb7HKC59rS0=";

  meta = {
    description = "Linux auto tiling manager with hot corner support for EWMH-compliant window managers";
    homepage = "https://github.com/leukipp/cortile";
    license = lib.licenses.mit;
    mainProgram = "cortile";
    platforms = lib.platforms.linux;
  };
}
