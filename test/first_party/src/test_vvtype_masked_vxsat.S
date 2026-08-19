#include "common/encoding.h"

.global main
main:
    # Save return address in a register unused by the test.
    mv t6, ra

    # Enable vector state and use four 8-bit elements.
    li t0, MSTATUS_VS
    csrs mstatus, t0
    vsetivli zero, 4, e8, m1, tu, mu

    # vsaddu overflows in every lane, but an all-zero mask must suppress both
    # the destination update and the vxsat side effect.
    vmv.v.i v1, -1
    vmv.v.i v2, 1
    li t2, 0x55
    vmv.v.x v3, t2
    vmclr.m v0
    csrwi vxsat, 0
    vsaddu.vv v3, v1, v2, v0.t

    csrr t0, vxsat
    bnez t0, fail
    vmv.x.s t0, v3
    li t1, 0x55
    bne t0, t1, fail

    # Once the mask enables the lanes, the same overflow must set vxsat and
    # write the saturated all-ones result.
    vmset.m v0
    vsaddu.vv v3, v1, v2, v0.t

    csrr t0, vxsat
    li t1, 1
    bne t0, t1, fail
    vmv.x.s t0, v3
    li t1, -1
    bne t0, t1, fail

    # Signed positive overflow must clamp to INT8_MAX and set vxsat.
    li t2, 127
    vmv.v.x v1, t2
    vmv.v.i v2, 1
    csrwi vxsat, 0
    vsadd.vv v3, v1, v2

    csrr t0, vxsat
    li t1, 1
    bne t0, t1, fail
    vmv.x.s t0, v3
    li t1, 127
    bne t0, t1, fail

    # A later non-saturating operation must not clear sticky vxsat.
    vmv.v.i v1, 10
    vmv.v.i v2, 1
    vsadd.vv v3, v1, v2

    csrr t0, vxsat
    li t1, 1
    bne t0, t1, fail
    vmv.x.s t0, v3
    li t1, 11
    bne t0, t1, fail

    # Signed negative overflow must clamp to INT8_MIN and set vxsat.
    li t2, -128
    vmv.v.x v1, t2
    vmv.v.i v2, -1
    csrwi vxsat, 0
    vsadd.vv v3, v1, v2

    csrr t0, vxsat
    li t1, 1
    bne t0, t1, fail
    vmv.x.s t0, v3
    li t1, -128
    bne t0, t1, fail

pass:
    li a0, 0
    mv ra, t6
    ret
fail:
    li a0, 1
    mv ra, t6
    ret
