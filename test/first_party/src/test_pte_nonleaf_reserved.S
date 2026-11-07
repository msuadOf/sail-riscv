#if __riscv_xlen == 32
#define LREG lw
#define SREG sw
#else
#define LREG ld
#define SREG sd
#endif
// 页表标准行为：经 mret 进入 S 态，检查数据、页故障 cause 和 tval。
.option norvc
.section .text
.global main
main:
    mv s0, ra
    li s1, 1
#if __riscv_xlen == 32
    la t0, root
    la t1, leaves
    srli t1, t1, 2
    ori t1, t1, 1
    sw t1, 512(t0) // VA 的 Sv32 根索引为 128。
    li t1, 0x200000cf
    li t2, 2048
    add t0, t0, t2
    sw t1, 0(t0) // S 态代码的 4 MiB 恒等映射。
    la t0, root
    srli t0, t0, 12
    li t1, 0x80000000
    or t0, t0, t1
    csrw satp, t0
#else
    la t0, root
    la t1, middle
    srli t1, t1, 2
    ori t1, t1, 1
    SREG t1, 0(t0)
    li t1, 0x200000cf
    SREG t1, 16(t0) // S 态代码的 1 GiB 恒等映射。
    la t0, middle
    la t1, leaves
    srli t1, t1, 2
    ori t1, t1, 1
    li t2, 2048
    add t0, t0, t2
    SREG t1, 0(t0)
    la t0, root
    srli t0, t0, 12
    li t1, 0x8000000000000000
    or t0, t0, t1
    csrw satp, t0
#endif
    la t0, gap_trap
    csrw mtvec, t0
    la t0, payload
    li t1, 0x12345678
    SREG t1, 0(t0)
    li t2, 0x5008
    add t0, t0, t2
    li t1, 0x23456789
    SREG t1, 0(t0)
    la t0, leaves
    la t1, payload
    srli t1, t1, 2
    ori t1, t1, 0xc7
    SREG t1, 0(t0)
    li a0, 0x20000000
    li a1, 13
    li a2, 0x12345678
    li a3, 0
    li s6, 0 // 分别检查根指针与中间指针。
level_loop:
    la s3, root
#if __riscv_xlen == 32
    addi s3, s3, 512
#endif
    beqz s6, selected
    la s3, middle
    li t0, 2048
    add s3, s3, t0
selected:
    LREG s4, 0(s3)
    li s5, 0x10
flag_loop:
    or t0, s4, s5
    SREG t0, 0(s3)
    sfence.vma
    call access
    li a1, 15
    li a3, 1
    call access
    li a1, 13
    li a3, 0
    addi s1, s1, 1
    slli s5, s5, 2
    li t0, 0x100
    blt s5, t0, flag_loop // U、A。
    ori t0, s4, 0x80 // D。
    SREG t0, 0(s3)
    sfence.vma
    call access
    li a1, 15
    li a3, 1
    call access
    li a1, 13
    li a3, 0
    addi s1, s1, 1
    li t0, 0x1f000041 // 指向 PMA 空洞，先报 PF 而非 AF。
    SREG t0, 0(s3)
    sfence.vma
    call access
    addi s1, s1, 1
    ori t0, s4, 0x20 // G 不是保留位，合法成功对照。
    SREG t0, 0(s3)
    sfence.vma
    li a1, 9
    call access
    SREG s4, 0(s3) // 进入下一用例前恢复合法指针。
    sfence.vma
    li a1, 13
    addi s6, s6, 1
#if __riscv_xlen == 32
    li t0, 1
#else
    li t0, 2
#endif
    blt s6, t0, level_loop
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
    LREG t3, 0(a0)
    ecall
1:  SREG a2, 0(a0)
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
