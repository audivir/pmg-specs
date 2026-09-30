#!/bin/sh
# Installs the given specs with pmg, which runs their tests, each in a fresh home and even if the
# system has the package; then installs them with the package manager of the system and checks
# that pmg uses that copy. Specs not for the host are skipped. PMG_SOURCE picks the pmg to test.
# Runs on the runners and as root in the Alpine, CentOS, and Rocky Linux containers, with uv in
# PATH; POSIX sh, as Alpine has no bash.
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
export PMG_SPECS_DIR="$root/specs"
export UV_TOOL_DIR="$work/tools" UV_TOOL_BIN_DIR="$work/bin" UV_PYTHON_INSTALL_DIR="$work/python"
export UV_PYTHON_PREFERENCE=only-managed
unset XDG_DATA_HOME XDG_BIN_HOME XDG_CACHE_HOME PMG_HOME

if command -v brew >/dev/null; then
  manager=brew
elif command -v apt-get >/dev/null; then
  manager=apt
elif command -v apk >/dev/null; then
  manager=apk
elif command -v dnf >/dev/null; then
  manager=dnf
elif command -v yum >/dev/null; then
  manager=yum
else
  echo "no known package manager" >&2
  exit 1
fi
sudo=""
[ "$(id -u)" = 0 ] || sudo=sudo

system_install() {
  case $manager in
    brew) brew install --quiet "$@" ;;
    apt) $sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "$@" ;;
    apk) $sudo apk add --quiet "$@" ;;
    dnf) $sudo dnf install -y -q "$@" ;;
    yum) $sudo yum install -y -q "$@" ;;
  esac
}

case $manager in
  apt) $sudo apt-get update -qq ;;
  # the specs name packages of EPEL, like ripgrep
  dnf) system_install epel-release ;;
  # CentOS 7 is end of life, its EPEL is only in the archive
  yum)
    system_install epel-release
    $sudo sed -i -e 's|^metalink=|#metalink=|' \
      -e 's|^#\?baseurl=.*/epel/7/|baseurl=https://archives.fedoraproject.org/pub/archive/epel/7/|' \
      /etc/yum.repos.d/epel.repo
    ;;
esac

uv tool install --quiet --python 3.13 \
  --from "${PMG_SOURCE:-https://github.com/audivir/pmg/archive/main.tar.gz}" pmg
pmg="$work/bin/pmg"

# the specs for the host, by the rules of pmg itself
names=$("$UV_TOOL_DIR/pmg/bin/python" -c '
import sys
from pmg.core import is_for_host, load_spec
print(" ".join(name for name in sys.argv[1:] if is_for_host(load_spec(name))))
' "$@")
for name in "$@"; do
  case " $names " in
    *" $name "*) ;;
    *) echo "skipped $name, not for this host" ;;
  esac
done

failed=""
for name in $names; do
  echo "::group::pmg install --no-external $name"
  home=$(mktemp -d "$work/home.XXXXXX")
  HOME="$home" "$pmg" install --no-external "$name" || failed="$failed $name"
  echo "::endgroup::"
done

# after the installs of pmg, so that their dependencies are not found on the system
for name in $names; do
  packages=$("$pmg" external "$name" | while read -r pm package; do
    [ "$pm" = "$manager" ] && echo "$package"
  done || true)
  if [ -z "$packages" ]; then
    echo "skipped the external $name, no $manager package"
    continue
  fi
  echo "::group::$manager install $packages, pmg install $name"
  home=$(mktemp -d "$work/home.XXXXXX")
  # shellcheck disable=SC2086 # the packages of a spec are separated by spaces
  if system_install $packages && HOME="$home" "$pmg" install "$name" &&
    HOME="$home" "$pmg" list | grep -q "^$name@external "; then
    :
  else
    echo "pmg did not find $name from $manager" >&2
    failed="$failed external:$name"
  fi
  echo "::endgroup::"
done

if [ -n "$failed" ]; then
  echo "failed:$failed" >&2
  exit 1
fi
