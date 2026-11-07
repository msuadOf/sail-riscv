// Svnapot：经 mret 进入 S 态，检查数据、页故障 cause 和 tval。
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
    la s2, payload
    srli s2, s2, 2
    li t0, 0x80000000000020c7
    or s2, s2, t0
    la s3, leaves
    sd s2, 0(s3)
    sd s2, 40(s3)
    sfence.vma
    li a0, 0x20000000
#ifdef SVNAPOT_DISABLED
    li a1, 13
    li a3, 0
    call access
    j done
#else
    li a1, 9
    li a2, 0x12345678
    li a3, 0
    call access
    addi s1, s1, 1
    li a0, 0x20005008
    li a2, 0x23456789
    call access
    addi s1, s1, 1
    li a0, 0x20000000 // 再次访问，覆盖 TLB 命中。
    li a2, 0x12345678
    call access
    addi s1, s1, 1
    li a3, 1 // 写入新值并在 M 态核验实际物理目标。
    li a2, 0x3456789a
    call access
    la t0, payload
    ld t1, 0(t0)
    bne t1, a2, fail
    ld t1, 0(s3)
    bne t1, s2, fail // 内存中的 PTE 仍是未替换的原值。
    addi s1, s1, 1
    li a3, 0
    li a1, 13
    li s4, 0
1:  li t0, 8
    beq s4, t0, 2f
    li t0, -15361 // 清除 PPN[3:0]。
    and t0, s2, t0
    slli t1, s4, 10
    or t0, t0, t1
    sd t0, 0(s3)
    sfence.vma
    call access
2:  addi s4, s4, 1
    li t0, 16
    blt s4, t0, 1b
    addi s1, s1, 1
    la t0, middle
    li t1, 0x80000000201000c7 // N=1 的高层叶。
    li t2, 2048
    add t0, t0, t2
    sd t1, 0(t0)
    sfence.vma
    call access
    addi s1, s1, 1
    // 恢复合法下级页表，保证这里只能由根指针的 N 触发 PF。
    sd s2, 0(s3)
    la t0, middle
    li t2, 2048
    add t0, t0, t2
    la t1, leaves
    srli t1, t1, 2
    ori t1, t1, 1
    sd t1, 0(t0)
    la t0, root
    ld t1, 0(t0)
    li t2, 0x8000000000000000 // N=1 的指针。
    or t1, t1, t2
    sd t1, 0(t0)
    sfence.vma
    call access
#endif
done:
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
