#!/usr/bin/env python3
"""Check the FD flag-update relation for both XLENs and extension domains.

This checks the state equation independently of the Sail implementation. The
instruction-level test must still run against IR generated from fdext_regs.sail.
"""

import subprocess


def concrete(old_fcsr, old_mstatus, flags, xlen, has_f, has_zfinx):
    old_flags = old_fcsr & 31
    new_flags = old_flags | flags
    changed = old_flags != new_flags
    allowed = not changed or has_f != has_zfinx
    dirty_mask = (3 << 13) | (1 << (xlen - 1))
    dirty_mstatus = old_mstatus | dirty_mask
    old_new_fcsr = (old_fcsr & ~31) | (new_flags if changed else old_flags)
    new_new_fcsr = (old_fcsr & ~31) | new_flags
    old_new_status = dirty_mstatus if changed and has_f else old_mstatus
    new_new_status = dirty_mstatus if changed and has_f else old_mstatus
    assert old_new_fcsr == new_new_fcsr
    assert old_new_status == new_new_status
    return allowed


def smt_case(xlen, has_f, has_zfinx):
    sd = 1 << (xlen - 1)
    mask = sd | (3 << 13)
    f = "true" if has_f else "false"
    z = "true" if has_zfinx else "false"
    dirty = f"(bvor (bvand ms #x{(~mask & ((1 << 64) - 1)):016x}) #x{mask:016x})"
    return f"""
(set-logic QF_BV)
(declare-const csr (_ BitVec 32))
(declare-const ms (_ BitVec 64))
(declare-const flags (_ BitVec 5))
(define-fun oldflags () (_ BitVec 5) ((_ extract 4 0) csr))
(define-fun newflags () (_ BitVec 5) (bvor oldflags flags))
(define-fun changed () Bool (not (= oldflags newflags)))
(define-fun old-domain () Bool (or (not changed) (not (= {f} {z}))))
(define-fun new-domain () Bool (or (not changed) (not (= {f} {z}))))
(define-fun old-csr () (_ BitVec 32)
  (ite changed (concat ((_ extract 31 5) csr) newflags) csr))
(define-fun new-csr () (_ BitVec 32)
  (concat ((_ extract 31 5) csr) newflags))
(define-fun old-ms () (_ BitVec 64)
  (ite (and changed {f}) {dirty} ms))
(define-fun new-ms () (_ BitVec 64)
  (ite {f} (ite changed {dirty} ms) ms))
(push 1)
(assert (or (xor old-domain new-domain)
            (and old-domain (or (not (= old-csr new-csr))
                                (not (= old-ms new-ms))))))
(check-sat)
(pop 1)
(push 1)
(assert (not changed))
(assert old-domain)
(check-sat)
(pop 1)
(push 1)
(assert changed)
(assert old-domain)
(check-sat)
(pop 1)
(push 1)
(assert changed)
(assert (not old-domain))
(check-sat)
(pop 1)
"""


def main():
    for xlen in (32, 64):
        for has_f, has_zfinx in ((True, False), (False, True), (False, False), (True, True)):
            result = subprocess.run(
                ["z3", "-in"], input=smt_case(xlen, has_f, has_zfinx),
                text=True, capture_output=True, check=True,
            )
            valid_extensions = has_f != has_zfinx
            expected = ["unsat", "sat", "sat" if valid_extensions else "unsat",
                        "unsat" if valid_extensions else "sat"]
            assert result.stdout.splitlines() == expected, (xlen, has_f, has_zfinx, result)
            for old_flags in range(32):
                for flags in range(32):
                    for old_status in (0, 0x2600, 0x4600, 0x8000000000006600, 0x5A5A5A5A5A5A5A5A):
                        old_fcsr = 0xA5A5A5A0 | old_flags
                        allowed = concrete(old_fcsr, old_status, flags, xlen, has_f, has_zfinx)
                        assert allowed == (old_flags | flags == old_flags or has_f != has_zfinx)
            print(f"XLEN={xlen} F={has_f} Zfinx={has_zfinx}: difference UNSAT, "
                  "domains checked; 1024 flag pairs checked")


if __name__ == "__main__":
    main()
