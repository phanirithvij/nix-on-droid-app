{ buildGoModule, fetchFromGitHub }:

buildGoModule (finalAttrs: {
  pname = "go-maven-resolver";
  version = "1.1.2";

  vendorHash = "sha256-dlqI+onfeo4tTwmHeq8heVKRzLU1gFEQ+4iv+8egN90=";

  src = fetchFromGitHub {
    owner = "status-im";
    repo = "go-maven-resolver";
    tag = "v${finalAttrs.version}";
    hash = "sha256-S7VyuRNyF+JepN0dN3hkZEsFIndNhwqO7u1fjXj5eFw=";
  };

  meta = {
    description = "go maven resolver";
    homepage = "https://github.com/status-im/go-maven-resolver";
    mainProgram = "go-maven-resolver";
  };
})
