#include "common/encoding.h"

.global main
main:
    mv t6, ra
    li t0, MSTATUS_FS | MSTATUS_VS
    csrs mstatus, t0

    # A boxed BF16 signaling NaN. Conversion gives a canonical f32 NaN
    # and NV, but an inactive vector instruction must not accrue NV.
    li t0, 0xffffffffffff7f81
    fmv.d.x f1, t0
    li t0, 0xffffffffffff3f80
    fmv.d.x f2, t0

    vsetivli zero, 4, e16, m1, tu, mu
    li t0, 0x3f80
    vmv.v.x v2, t0
    vmv.v.x v6, t0
    vsetivli zero, 4, e32, m2, tu, mu
    li t0, 0x3f800000
    vmv.v.x v4, t0

    # vl=0, with initial flags both clear and nonzero.
    vsetivli zero, 0, e16, m1, tu, mu
    csrwi fflags, 0
    vfwmaccbf16.vf v4, f1, v2
    csrr t0, fflags
    bnez t0, fail_vl_zero
    csrwi fflags, 1
    vfwmaccbf16.vf v4, f1, v2
    csrr t0, fflags
    li t1, 1
    bne t0, t1, fail

    # All mask bits clear at vl=4.
    vsetivli zero, 4, e16, m1, tu, mu
    vmclr.m v0
    csrwi fflags, 0
    vfwmaccbf16.vf v4, f1, v2, v0.t
    csrr t0, fflags
    bnez t0, fail
    csrwi fflags, 1
    vfwmaccbf16.vf v4, f1, v2, v0.t
    csrr t0, fflags
    li t1, 1
    bne t0, t1, fail

    # vstart=vl=2 is legal and has no active element.
    vsetivli zero, 2, e16, m1, tu, mu
    li t0, 2
    csrw vstart, t0
    csrwi fflags, 0
    vfwmaccbf16.vf v4, f1, v2
    csrr t0, fflags
    bnez t0, fail
    li t0, 2
    csrw vstart, t0
    csrwi fflags, 1
    vfwmaccbf16.vf v4, f1, v2
    csrr t0, fflags
    li t1, 1
    bne t0, t1, fail

    # One active lane must set NV, preserving a preexisting NX bit.
    vsetivli zero, 4, e16, m1, tu, mu
    vmclr.m v0
    li t0, 1
    vmv.s.x v0, t0
    csrwi fflags, 0
    vfwmaccbf16.vf v4, f1, v2, v0.t
    csrr t0, fflags
    li t1, 0x10
    bne t0, t1, fail
    csrwi fflags, 1
    vfwmaccbf16.vf v4, f1, v2, v0.t
    csrr t0, fflags
    li t1, 0x11
    bne t0, t1, fail

    # The active result is the canonical f32 NaN; inactive lane 1 is intact.
    vsetivli zero, 4, e32, m2, tu, mu
    vmv.x.s t0, v4
    li t1, 0x7fc00000
    bne t0, t1, fail
    vslidedown.vi v8, v4, 1
    vmv.x.s t0, v8
    li t1, 0x3f800000
    bne t0, t1, fail

    # A signaling NaN only in the vstart-skipped source prefix is inert.
    vsetivli zero, 4, e16, m1, tu, mu
    li t0, 0x3f80
    vmv.v.x v2, t0
    li t0, 0x7f81
    vmv.s.x v2, t0
    vsetivli zero, 4, e32, m2, tu, mu
    li t0, 0x3f800000
    vmv.v.x v4, t0
    vsetivli zero, 2, e16, m1, tu, mu
    li t0, 1
    csrw vstart, t0
    csrwi fflags, 0
    vfwmaccbf16.vf v4, f2, v2
    csrr t0, fflags
    bnez t0, fail
    vsetivli zero, 4, e32, m2, tu, mu
    vmv.x.s t0, v4
    li t1, 0x3f800000
    bne t0, t1, fail
    vslidedown.vi v8, v4, 1
    vmv.x.s t0, v8
    li t1, 0x40000000
    bne t0, t1, fail

    # VV already converts each source inside the active-lane branch.
    vsetivli zero, 4, e16, m1, tu, mu
    vmclr.m v0
    li t0, 0x7f81
    vmv.v.x v6, t0
    csrwi fflags, 1
    vfwmaccbf16.vv v4, v6, v2, v0.t
    csrr t0, fflags
    li t1, 1
    bne t0, t1, fail
    li t0, 1
    vmv.s.x v0, t0
    csrwi fflags, 1
    vfwmaccbf16.vv v4, v6, v2, v0.t
    csrr t0, fflags
    li t1, 0x11
    bne t0, t1, fail

pass:
    li a0, 0
    mv ra, t6
    ret
fail:
    li a0, 1
    mv ra, t6
    ret
fail_vl_zero:
    li a0, 2
    mv ra, t6
    ret
