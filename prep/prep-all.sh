#!/usr/bin/env bash
# Setup lab (bila belum) lalu semua prep berurutan. Soal yang gagal dicatat, prep lain tetap jalan.
# Pemakaian: ./prep-all.sh           -> semua soal (1-21)
#            ./prep-all.sh 2 5 18    -> soal tertentu saja
cd "$(dirname "$(readlink -f "$0")")" || exit 1
[ "$(id -u)" -eq 0 ] || exec sudo -E bash "$(readlink -f "$0")" "$@"
[ -f /var/lib/ex294-prep/setup.done ] || ./setup-lab.sh || exit 1
LIST=("$@"); [ ${#LIST[@]} -gt 0 ] || LIST=($(seq 1 21))
FAILED=()
for n in "${LIST[@]}"; do
  f="$(printf 'prep-q%02d.sh' "$n")"
  [ -x "$f" ] || { echo "Tidak ada $f"; FAILED+=("$n"); continue; }
  echo "================ $f"
  ./"$f" </dev/null || FAILED+=("$n")
done
echo
if [ ${#FAILED[@]} -eq 0 ]; then echo "Semua prep selesai."; else echo "Prep gagal untuk soal: ${FAILED[*]}"; exit 1; fi
