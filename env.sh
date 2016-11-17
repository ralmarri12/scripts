#!/usr/bin/env bash
# Copyright 2016 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

#
# Source this script to include variable useful functions in your environment.
#
# Functions prefixed with 'f' are for fuchsia.
# Functions prefixed with 'm' are for magenta.
#

export FUCHSIA_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export FUCHSIA_DIR="$(dirname "${FUCHSIA_SCRIPTS_DIR}")"
export MAGENTA_DIR="${FUCHSIA_DIR}/magenta"

### envhelp : print usage for command or list of commands

function envhelp() {
  if [[ $# -ne 1 ]]; then
    # note: please keep these sorted
    cat <<END
magenta functions:
  mboot, mbuild, mcheck, mgo, mrun, mset, msymbolize
fuchsia functions:
  fboot, fbuild, fbuild-sysroot, fbuild-sysroot-if-needed, fcheck, fgen,
  fgen-if-needed, fgo, frun, fset, fsymbolize
END
    return
  fi
  $1-usage
}

### mgo: navigate to directory within magenta

function mgo-usage() {
  cat >&2 <<END
Usage: mgo [dir]
Navigates to directory within magenta.
END
}

function mgo() {
  if [[ $# -gt 1 ]]; then
    mgo-usage
    return 1
  fi

  cd "${MAGENTA_DIR}/$1"
}

### mset: set magenta build properties

function mset-usage() {
  cat >&2 <<END
Usage: mset x86-64|arm32|arm64
Sets magenta build options.
END
}

function mset() {
  if [[ $# -ne 1 ]]; then
    mset-usage
    return 1
  fi

  local settings="$*"

  case $1 in
    x86-64)
      export MAGENTA_PROJECT=magenta-pc-x86-64
      export MAGENTA_ARCH=x86-64
      ;;
    arm32)
      export MAGENTA_PROJECT=magenta-qemu-arm32
      export MAGENTA_ARCH=arm32
      ;;
    arm64)
      export MAGENTA_PROJECT=magenta-qemu-arm64
      export MAGENTA_ARCH=arm64
      ;;
    *)
      mset-usage
      return 1
  esac

  export MAGENTA_BUILD_DIR="${MAGENTA_DIR}/build-${MAGENTA_PROJECT}"
  export MAGENTA_TOOLS_DIR="${MAGENTA_DIR}/build-${MAGENTA_PROJECT}/tools"
  export MAGENTA_SETTINGS="${settings}"

  # add tools to path, removing prior tools directory if any
  export PATH="${PATH//:${MAGENTA_DIR}\/build-*\/tools}:${MAGENTA_TOOLS_DIR}"
}

### mcheck: checks whether mset was run

function mcheck-usage() {
  cat >&2 <<END
Usage: mcheck
Checks whether magenta build options have been set.
END
}

function mcheck() {
  if [[ -z "${MAGENTA_SETTINGS}" ]]; then
    echo "must run mset first" >&2
    return 1
  fi
  return 0
}

### mbuild: build magenta

function mbuild-usage() {
  cat >&2 <<END
Usage: mbuild [extra make args...]
Builds magenta.
END
}

function mbuild() {
  mcheck || return 1

  echo "Building magenta..."
  "${MAGENTA_DIR}/scripts/make-parallel" -C "${MAGENTA_DIR}" "${MAGENTA_PROJECT}" "$@"
}

### mboot: run magenta bootserver

function mboot-usage() {
  cat >&2 <<END
Usage: mboot [extra bootserver args...]
Runs magenta system bootserver.
END
}

function mboot() {
  mcheck || return 1

  "${MAGENTA_TOOLS_DIR}/bootserver" "${MAGENTA_BUILD_DIR}/magenta.bin" "$@"
}

### mrun: run magenta in qemu

function mrun-usage() {
  cat >&2 <<END
Usage: mrun [extra qemu args...]
Runs magenta system in qemu.
END
}

function mrun() {
  mcheck || return 1

  "${MAGENTA_DIR}/scripts/run-magenta" -a "${MAGENTA_ARCH}" "$@"
}

### msymbolize: symbolizes stack traces

function msymbolize-usage() {
  cat >&2 <<END
Usage: msymbolize [extra symbolize args...]
Symbolizes stack trace from standard input.
END
}

function msymbolize() {
  mcheck || return 1

  # TODO(jeffbrown): Fix symbolize to support arch other than x86-64
  "${MAGENTA_DIR}/scripts/symbolize" "$@"
}

### fgo: navigate to directory within fuchsia

function fgo-usage() {
  cat >&2 <<END
Usage: fgo [dir]
Navigates to directory within fuchsia root.
END
}

function fgo() {
  if [[ $# -gt 1 ]]; then
    fgo-usage
    return 1
  fi

  cd "${FUCHSIA_DIR}/$1"
}

### fset: set fuchsia build properties

function fset-usage() {
  cat >&2 <<END
Usage: fset x86-64|arm64 [--release] [--modules m1,m2...] [--goma] [--ccache]
Sets fuchsia built options.
END
}

function fset-add-gen-arg() {
  export FUCHSIA_GEN_ARGS="${FUCHSIA_GEN_ARGS} $*"
}

function fset() {
  if [[ $# -lt 1 ]]; then
    fset-usage
    return 1
  fi

  local settings="$*"
  export FUCHSIA_GEN_ARGS=
  export FUCHSIA_VARIANT=debug

  case $1 in
    x86-64)
      mset x86-64
      # TODO(jeffbrown): we should really align these
      export FUCHSIA_GEN_TARGET=x86-64
      export FUCHSIA_SYSROOT_TARGET=x86_64
      ;;
    arm64)
      mset arm64
      export FUCHSIA_GEN_TARGET=aarch64
      export FUCHSIA_SYSROOT_TARGET=aarch64
      ;;
    *)
      fset-usage
      return 1
  esac
  fset-add-gen-arg --target_cpu "${FUCHSIA_GEN_TARGET}"
  shift

  while [[ $# -ne 0 ]]; do
    case $1 in
      --release)
        fset-add-gen-arg --release
        export FUCHSIA_VARIANT=release
        ;;
      --modules)
        if [[ $# -lt 1 ]]; then
          fset-usage
          return 1
        fi
        fset-add-gen-arg --modules $2
        shift
        ;;
      --goma)
        fset-add-gen-arg --goma
        ;;
      --ccache)
        fset-add-gen-arg --ccache
        ;;
      *)
        fset-usage
        return 1
    esac
    shift
  done

  export FUCHSIA_OUT_DIR="${FUCHSIA_DIR}/out"
  export FUCHSIA_BUILD_DIR="${FUCHSIA_OUT_DIR}/${FUCHSIA_VARIANT}-${FUCHSIA_GEN_TARGET}"
  export FUCHSIA_BUILD_NINJA="${FUCHSIA_BUILD_DIR}/build.ninja"
  export FUCHSIA_GEN_ARGS_CACHE="${FUCHSIA_BUILD_DIR}/build.last-gen-args"
  export FUCHSIA_SYSROOT_DIR="${FUCHSIA_OUT_DIR}/sysroot/${FUCHSIA_SYSROOT_TARGET}-fuchsia"
  export FUCHSIA_SETTINGS="${settings}"
}

### fcheck: checks whether fset was run

function fcheck-usage() {
  cat >&2 <<END
Usage: fcheck
Checks whether fuchsia build options have been set.
END
}

function fcheck() {
  if [[ -z "${FUCHSIA_SETTINGS}" ]]; then
    echo "must run fset first" >&2
    return 1
  fi
  return 0
}

### fgen: generate ninja build files

function fgen-usage() {
  cat >&2 <<END
Usage: fgen [extra gen.py args...]
Generates ninja build files for fuchsia.
END
}

function fgen() {
  fcheck || return 1

  echo "Generating ninja files..."
  rm -f "${FUCHSIA_GEN_ARGS_CACHE}"
  "${FUCHSIA_DIR}/packages/gn/gen.py" ${FUCHSIA_GEN_ARGS} "$@" \
    && (echo "${FUCHSIA_GEN_ARGS}" > "${FUCHSIA_GEN_ARGS_CACHE}")
}

### fgen-if-needed: only generate ninja build files if they are absent

function fgen-if-needed-usage() {
  cat >&2 <<END
Usage: fgen-if-needed [extra gen.py args...]
Generates ninja build files for fuchsia only if needed.
Caveat: This might not catch all cases where fgen is actually needed.
END
}

function fgen-if-needed() {
  fcheck || return 1

  local last_gen_args
  if [[ -f "${FUCHSIA_GEN_ARGS_CACHE}" ]]; then
    last_gen_args=$(cat "${FUCHSIA_GEN_ARGS_CACHE}")
  fi

  if ! ([[ -f "${FUCHSIA_BUILD_NINJA}" ]] \
      && [[ "${FUCHSIA_GEN_ARGS}" == "${last_gen_args}" ]]); then
    fgen "$@"
  fi
}

### fsysroot: build sysroot

function fbuild-sysroot-usage() {
  cat >&2 <<END
Usage: fbuild-sysroot [extra build-sysroot.sh args...]
Builds fuchsia system root.
END
}

function fbuild-sysroot() {
  fcheck || return 1

  echo "Building sysroot..."
  (fgo && "./scripts/build-sysroot.sh" -t "${FUCHSIA_SYSROOT_TARGET}" "$@")
}

### fbuild-sysroot-if-needed: only build sysroot if absent

function fbuild-sysroot-if-needed-usage() {
  cat >&2 <<END
Usage: fbuild-sysroot-if-needed [extra build-sysroot.sh args...]
Builds fuchsia system root only if needed.
Caveat: This might not catch all cases where fbuild-sysroot is actually needed.
END
}

function fbuild-sysroot-if-needed() {
  fcheck || return 1

  # TODO(jeffbrown): Try to detect whether we need to rebuild.
  if ! [[ -d "${FUCHSIA_SYSROOT_DIR}" ]]; then
    fbuild-sysroot "$@"
  fi
}

### fbuild: build fuchsia

function fbuild-usage() {
  cat >&2 <<END
Usage: fbuild [extra ninja args...]
Builds fuchsia.
END
}

function fbuild() {
  fcheck || return 1

  fgen-if-needed \
    && fbuild-sysroot-if-needed \
    && echo "Building fuchsia..." \
    && "${FUCHSIA_DIR}/buildtools/ninja" -C "${FUCHSIA_BUILD_DIR}" "$@"
}

### fboot: run fuchsia bootserver

function fboot-usage() {
  cat >&2 <<END
Usage: fboot [extra bootserver args...]
Runs fuchsia system bootserver.
END
}

function fboot() {
  fcheck || return 1

  mboot "${FUCHSIA_BUILD_DIR}/user.bootfs" "$@"
}

### frun: run fuchsia in qemu

function frun-usage() {
  cat >&2 <<END
Usage: frun [extra qemu args...]
Runs fuchsia system in qemu.
END
}

function frun() {
  fcheck || return 1

  "${MAGENTA_DIR}/scripts/run-magenta" -a "${MAGENTA_ARCH}" "$@"
}

### fsymbolize: symbolizes stack traces with fuchsia build

function fsymbolize-usage() {
  cat >&2 <<END
Usage: fsymbolize [extra symbolize args...]
Symbolizes stack trace from standard input.
END
}

function fsymbolize() {
  fcheck || return 1

  msymbolize --build-dir "${FUCHSIA_BUILD_DIR}" "$@"
}
