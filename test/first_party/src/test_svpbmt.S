// 页表标准行为：经 mret 进入 S 态，检查数据、页故障 cause 和 tval。
.option norvc
.section .text
.global main
main:
    mv s0, ra
    li s1, 1
    la t0, root
    la t1, middle
    srli t1, t1, 2
    ori t1, t1, 1
    sd t1, 0(t0)
    li t1, 0x200000cf
    sd t1, 16(t0) // S 态代码的 1 GiB 恒等映射。
    la t0, middle
    la t1, leaves
    srli t1, t1, 2
    ori t1, t1, 1
    li t2, 2048
    add t0, t0, t2
    sd t1, 0(t0)
    la t0, root
    srli t0, t0, 12
    li t1, 0x8000000000000000
    or t0, t0, t1
    csrw satp, t0
    la t0, gap_trap
    csrw mtvec, t0
    la t0, payload
    li t1, 0x12345678
    sd t1, 0(t0)
    li t2, 0x5008
    add t0, t0, t2
    li t1, 0x23456789
    sd t1, 0(t0)
    li s2, 0x4000000000000000
    csrr t0, menvcfg
    and t0, t0, s2
    bnez t0, fail // 复位 PBMTE 必须为 0。
    csrs menvcfg, s2
    csrr t0, menvcfg
    and t0, t0, s2
#ifdef SVPBMT_DISABLED
    bnez t0, fail
#else
    beqz t0, fail
#endif
    addi s1, s1, 1
    csrc menvcfg, s2
    la s3, leaves
    la s4, payload
    srli s4, s4, 2
    ori s4, s4, 0xc7
    li a0, 0x20000000
    li a1, 13
    li a2, 0x12345678
    li a3, 0
    li s5, 1
1:  slli t0, s5, 61
    or t0, t0, s4
    sd t0, 0(s3)
    sfence.vma
    call access
    li a1, 15
    li a3, 1
    call access
    li a1, 13
    li a3, 0
    addi s5, s5, 1
    li t0, 4
    blt s5, t0, 1b
#ifndef SVPBMT_DISABLED
    csrs menvcfg, s2
    li s5, 1
2:  slli t0, s5, 61
    or t0, t0, s4
    sd t0, 0(s3)
    sfence.vma
    li a1, 9
    call access
    // PBMT=01/10 均允许访存；验证 STORE 的实际物理目标。
    li a3, 1
    li a2, 0x3456789a
    call access
    la t0, payload
    ld t1, 0(t0)
    bne t1, a2, fail
    li t1, 0x12345678
    sd t1, 0(t0)
    mv a2, t1
    li a3, 0
    addi s1, s1, 1
    addi s5, s5, 1
    li t0, 3
    blt s5, t0, 2b
    li t0, 0x6000000000000000
    or t0, t0, s4
    sd t0, 0(s3)
    sfence.vma
    li a1, 13
    call access
    sd s4, 0(s3)
    la t0, middle
    li t2, 2048
    add t0, t0, t2
    ld t1, 0(t0)
    li t2, 0x2000000000000000
    or t1, t1, t2
    sd t1, 0(t0)
    sfence.vma
    call access
#endif
    li a0, 0
    csrw satp, zero
    mv ra, s0
    ret
// a0=VA，a1=预期 cause（9 表示成功后的 ecall），a2=数据，a3=是否 STORE。
access:
    la t0, s_access
    csrw mepc, t0
    li t0, 0x1800
    csrc mstatus, t0
    li t0, 0x800
    csrs mstatus, t0
    mret
s_access:
    bnez a3, 1f
    ld t3, 0(a0)
    ecall
1:  sd a2, 0(a0)
    ecall
.balign 4
gap_trap:
    csrr t1, mcause
    csrr t2, mtval
    la t0, m_resume
    csrw mepc, t0
    li t0, 0x1800
    csrs mstatus, t0
    mret
m_resume:
    bne t1, a1, fail
    li t0, 9
    bne a1, t0, 1f
    bnez a3, 2f
    bne t3, a2, fail
    j 2f
1:  bne t2, a0, fail
2:  ret
fail:
    csrw satp, zero
    mv a0, s1
    tail htif_exit
.section .bss
.balign 4096
root: .zero 4096
middle: .zero 4096
leaves: .zero 4096
.balign 65536
payload: .zero 65536
