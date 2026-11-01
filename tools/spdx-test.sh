#!/bin/sh
# [utest->req~chaine-de-verification-du-moteur~1]
# Test de la porte des en-têtes de licence (tools/spdx.sh) sur son cas
# d'échec (R3) : un fichier Rust sans en-tête fait échouer la porte, un
# manifeste sans en-tête aussi ; un arbre conforme passe. POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

mkdir -p "${TMP}/src" "${TMP}/tests"
printf '# SPDX-License-Identifier: EUPL-1.2\n[package]\n' > "${TMP}/Cargo.toml"
printf '// SPDX-License-Identifier: EUPL-1.2\n//! Bibliothèque.\n' > "${TMP}/src/lib.rs"
printf '// SPDX-License-Identifier: EUPL-1.2\n' > "${TMP}/tests/bout.rs"

echo "spdx-test — [A] arbre conforme : admis"
if ! sh "${ROOT}/tools/spdx.sh" "${TMP}" >/dev/null 2>&1; then
    echo "ÉCHEC [A] : un arbre conforme est refusé" >&2 ; fail=1
fi

echo "spdx-test — [B] fichier Rust sans en-tête : refusé"
printf '//! Sans en-tête.\n' > "${TMP}/src/nu.rs"
if sh "${ROOT}/tools/spdx.sh" "${TMP}" >/dev/null 2>&1; then
    echo "ÉCHEC [B] : un fichier sans en-tête est admis" >&2 ; fail=1
fi
rm "${TMP}/src/nu.rs"

echo "spdx-test — [C] en-tête au-delà de la troisième ligne : refusé"
printf '//! a\n//! b\n//! c\n// SPDX-License-Identifier: EUPL-1.2\n' > "${TMP}/tests/tard.rs"
if sh "${ROOT}/tools/spdx.sh" "${TMP}" >/dev/null 2>&1; then
    echo "ÉCHEC [C] : un en-tête tardif est admis" >&2 ; fail=1
fi
rm "${TMP}/tests/tard.rs"

echo "spdx-test — [D] manifeste sans en-tête : refusé"
printf '[package]\n' > "${TMP}/Cargo.toml"
if sh "${ROOT}/tools/spdx.sh" "${TMP}" >/dev/null 2>&1; then
    echo "ÉCHEC [D] : un manifeste sans en-tête est admis" >&2 ; fail=1
fi

exit "${fail}"
