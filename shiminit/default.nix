{ stdenv, lib }:

stdenv.mkDerivation rec {
  pname = "shiminit";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ ];
  buildInputs = [ ];

  makeFlags = [ "PREFIX=$(out)" ];

  meta = with lib; {
    description = "Minimal init program for booting NixOS in QEMU";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
