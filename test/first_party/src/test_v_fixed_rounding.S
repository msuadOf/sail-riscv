#include "common/encoding.h"

.global main
main:
    # Save return address in a register unused by the test.
    mv t6, ra

    li t0, MSTATUS_VS
    csrs mstatus, t0
    vsetivli zero, 4, e8, m1, tu, mu
    li t3, 2

    # RNU: 0x52 >> 2 is 20 with a set rounding bit, so round to 21.
    li t2, 0x52
    vmv.v.x v1, t2
    csrwi vxrm, 0
    vssrl.vx v2, v1, t3
    vmv.x.s t0, v2
    li t1, 21
    bne t0, t1, fail

    # RNE tie-to-even: discarded bits are exactly 0b10 and quotient is even.
    csrwi vxrm, 1
    vssrl.vx v2, v1, t3
    vmv.x.s t0, v2
    li t1, 20
    bne t0, t1, fail

    # RNE with a sticky bit must round the same even quotient upward.
    li t2, 0x53
    vmv.v.x v1, t2
    vssrl.vx v2, v1, t3
    vmv.x.s t0, v2
    li t1, 21
    bne t0, t1, fail

    # RDN never increments.
    csrwi vxrm, 2
    vssrl.vx v2, v1, t3
    vmv.x.s t0, v2
    li t1, 20
    bne t0, t1, fail

    # ROD increments an even quotient when any discarded bit is set.
    li t2, 0x52
    vmv.v.x v1, t2
    csrwi vxrm, 3
    vssrl.vx v2, v1, t3
    vmv.x.s t0, v2
    li t1, 21
    bne t0, t1, fail

    # ROD leaves an already-odd quotient unchanged.
    li t2, 0x56
    vmv.v.x v1, t2
    vssrl.vx v2, v1, t3
    vmv.x.s t0, v2
    li t1, 21
    bne t0, t1, fail

    # A zero shift never rounds, regardless of vxrm.
    li t3, 0
    vssrl.vx v2, v1, t3
    vmv.x.s t0, v2
    li t1, 0x56
    bne t0, t1, fail

pass:
    li a0, 0
    mv ra, t6
    ret
fail:
    li a0, 1
    mv ra, t6
    ret
