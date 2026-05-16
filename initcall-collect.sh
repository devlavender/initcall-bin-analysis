#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only

###############################################################################
# COPYRIGHT NOTICE:
#
# Copyright (C) 2026, Agatha Isabelle Moreira <code@agatha.dev>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2 of the license only.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see 
# <https://www.gnu.org/licenses/old-licenses/gpl-2.0.txt>.
#
# collect-initcall-build-data.sh
#
# Collects standardized build artifacts related to initcall symbols for later
# comparison across kernel builds.
#
# Intended usage is something like:
#
#   STORE=/data/initcall-analysis \
#   ./collect-initcall-build-data.sh pre-change clang-lto-prel32
#
# Result path:
#
#   $STORE/<build-scenario>/<config-scenario>/
#
# The default behavior when data is already present for a pair of build/config
# scenario is to refuse overwritting existing data.
#

set -eu

die() {
        printf 'error: %s\n' "$*" >&2
        exit 1
}

require_file() {
        echo "Checking required file $1"
        test -f "$1" || die "missing required file: $1"
}

refuse_existing() {
        echo "Checking if $1 exists"
        test -e "$1" && die "refusing to overwrite existing file: $1" \
                || return 0
}

write_cmd_output() {
        outfile="$1"
        shift 1

        refuse_existing "$outfile"

        echo "Generating ${outfile}"

        "$@" > "$outfile"
}

copy_file() {
        src="$1"
        dst="$2"

        require_file "$src"
        refuse_existing "$dst"

        echo "Copying ${src} to ${dst}"
        cp "$src" "$dst"
}

check_and_make() {
        test -f "$1" || make "$1"
}

###############################################################################
# parsing arguments
###############################################################################

test "$#" -eq 2 || die "usage: STORE=/path $(basename "$0") BUILD_SCENARIO " \
        "CONFIG_SCENARIO"

BUILD_SCENARIO="$1"
CONFIG_SCENARIO="$2"

SUFFIX="${BUILD_SCENARIO}-${CONFIG_SCENARIO}"
echo "Running with BUILD ${BUILD_SCENARIO} CONFIG ${CONFIG_SCENARIO} " \
        "(suffix: ${SUFFIX})" 

STORE="${STORE:-}"

test -n "$STORE" || die "STORE environment variable not set"

OUTDIR="${STORE}/${BUILD_SCENARIO}/${CONFIG_SCENARIO}"

mkdir -p "$OUTDIR"

###############################################################################
# generate missing artifacts
###############################################################################

for art in init/main.i init/main.s init/main.o vmlinux; do
        check_and_make "${art}"
        require_file "${art}"
done

###############################################################################
# metadata
###############################################################################

META="${OUTDIR}/metadata-${SUFFIX}.txt"

refuse_existing "$META"

cat > "$META" <<EOF
build_scenario=${BUILD_SCENARIO}
config_scenario=${CONFIG_SCENARIO}
files_suffix=-${SUFFIX}
kernel_tree=$(pwd)
timestamp=$(date)
EOF

###############################################################################
# raw artifacts
###############################################################################

copy_file "vmlinux" "${OUTDIR}/vmlinux-${SUFFIX}"
copy_file "init/main.o" "${OUTDIR}/init-main.o-${SUFFIX}"
copy_file "init/main.i" "${OUTDIR}/init-main.i-${SUFFIX}"
copy_file "init/main.s" "${OUTDIR}/init-main.s-${SUFFIX}"
copy_file ".config" "${OUTDIR}/kernel.config-${SUFFIX}"

###############################################################################
# symbol tables
###############################################################################

write_cmd_output "${OUTDIR}/nm-vmlinux-${SUFFIX}.txt" nm -n vmlinux
write_cmd_output "${OUTDIR}/nm-init-main-${SUFFIX}.o.txt" nm -n init/main.o

###############################################################################
# readelf
###############################################################################

write_cmd_output "${OUTDIR}/readelf-sections-vmlinux-${SUFFIX}.txt" \
        readelf -SW vmlinux
write_cmd_output "${OUTDIR}/readelf-sections-init-main.o-${SUFFIX}.txt" \
        readelf -SW init/main.o
write_cmd_output "${OUTDIR}/readelf-symbols-vmlinux-${SUFFIX}.txt" \
        readelf -sW vmlinux
write_cmd_output "${OUTDIR}/readelf-symbols-init-main.o-${SUFFIX}.txt" \
        readelf -sW init/main.o
write_cmd_output "${OUTDIR}/readelf-relocations-vmlinux-${SUFFIX}.txt" \
        readelf -rW vmlinux
write_cmd_output "${OUTDIR}/readelf-relocations-init-main.o-${SUFFIX}.txt" \
        readelf -rW init/main.o

###############################################################################
# objdump
###############################################################################

write_cmd_output "${OUTDIR}/objdump-headers-vmlinux-${SUFFIX}.txt" \
        objdump -h vmlinux
write_cmd_output "${OUTDIR}/objdump-headers-init-main.o-${SUFFIX}.txt" \
        objdump -h init/main.o
write_cmd_output "${OUTDIR}/objdump-disassembly-vmlinux-${SUFFIX}.txt" \
        objdump -drwC vmlinux
write_cmd_output "${OUTDIR}/objdump-disassembly-init-main.o-${SUFFIX}.txt" \
        objdump -drwC init/main.o

###############################################################################
# initcall sections
###############################################################################

INITCALL_LIST="${OUTDIR}/initcall-sections-${SUFFIX}.txt"

refuse_existing "$INITCALL_LIST"

readelf -SW vmlinux | awk '{print $2}' | grep '^\.initcall' | sort -u \
        > "$INITCALL_LIST"

###############################################################################
# dump all initcall sections
###############################################################################

while IFS= read -r section; do
        test -n "$section" || continue

        safe_name="$(printf '%s' "$section" | sed 's#[/.]#_#g')"

        write_cmd_output \
                "${OUTDIR}/objdump-section-${safe_name}-${SUFFIX}.txt" \
                objdump -s -j "$section" vmlinux

        write_cmd_output \
                "${OUTDIR}/readelf-section-${safe_name}-${SUFFIX}.txt" \
                readelf -x "$section" vmlinux

done < "$INITCALL_LIST"

printf 'done: %s\n' "$OUTDIR"