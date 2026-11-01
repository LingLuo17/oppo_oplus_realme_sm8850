#!/usr/bin/env python3
"""Point FinaSU's SUSFS Inline check at absolute paths.

FinaSU runs tools/check_susfs_inline.sh through $(KSU_KERNEL_DIR), which is
relative to the O= output tree. When the kernel is built out of tree, $(shell)
resolves that path from the make working directory and cannot find the script.
Rewrite the check line so the script and the kernel source root are absolute.
"""

import sys

if len(sys.argv) != 3:
    sys.exit("usage: finasu_inline_path.py <ksu-kernel-dir> <kernel-src-dir>")

ksu_dir, src_dir = sys.argv[1], sys.argv[2]
kbuild = ksu_dir + "/Kbuild"
script = ksu_dir + "/tools/check_susfs_inline.sh"
old = 'SUSFS_INLINE_CHECK_RESULT := $(shell $(KSU_KERNEL_DIR)/tools/check_susfs_inline.sh "$(srctree)"; echo $$?)'
new = 'SUSFS_INLINE_CHECK_RESULT := $(shell %s "%s"; echo $$?)' % (script, src_dir)

text = open(kbuild, encoding="utf-8").read()
if old not in text:
    print("FinaSU: SUSFS Inline check line not found; leaving Kbuild unchanged")
    sys.exit(0)
open(kbuild, "w", encoding="utf-8").write(text.replace(old, new, 1))
print("FinaSU: SUSFS Inline check now uses absolute paths")
