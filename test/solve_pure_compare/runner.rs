// Execute the generated small IR with Isla, including its ordinary Sail body.
// A temporary Cargo manifest supplies the isla-lib path dependency.

use isla_lib::bitvector::b64::B64;
use isla_lib::config::{ISAConfig, Tool};
use isla_lib::executor::{execute_ir_function, Run};
use isla_lib::init::initialize_architecture;
use isla_lib::ir::{AssertionMode, IRTypeInfo, Name, Symtab, Val};
use isla_lib::ir_lexer::new_ir_lexer;
use isla_lib::ir_parser::IrParser;
use isla_lib::smt::smtlib::Exp;
use isla_lib::smt::{configure_tastic, SmtResult, Sym, Tactic};
use isla_lib::source_loc::SourceLoc;
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::Mutex;

fn empty_tool() -> Tool {
    Tool {
        executable: PathBuf::new(),
        options: Vec::new(),
    }
}

fn empty_config() -> ISAConfig<B64> {
    ISAConfig {
        pc: Name::from_u32(u32::MAX),
        register_event_sets: HashMap::new(),
        assembler: empty_tool(),
        objdump: empty_tool(),
        nm: empty_tool(),
        linker: empty_tool(),
        page_table_base: 0,
        page_size: 0,
        s2_page_table_base: 0,
        s2_page_size: 0,
        default_page_table_setup: String::new(),
        thread_base: 0,
        thread_top: 0,
        thread_stride: 0,
        symbolic_addr_base: 0,
        symbolic_addr_top: 0,
        symbolic_addr_stride: 0,
        default_registers: HashMap::new(),
        reset_registers: Vec::new(),
        reset_constraints: Vec::new(),
        const_primops: HashMap::new(),
        function_assumptions: Vec::new(),
        register_renames: HashMap::new(),
        ignored_registers: HashSet::new(),
        relaxed_registers: HashSet::new(),
        probes: HashSet::new(),
        probe_functions: HashSet::new(),
        trace_functions: HashSet::new(),
        translation_function: None,
        in_program_order: HashSet::new(),
        default_sizeof: 0,
        zero_announce_exit: false,
        memory_regions: None,
        page_table_config: None,
        pmp: None,
        clint_enabled: None,
        execution_limits: None,
    }
}

// 比较每条完整未知输入路径上的完整输出，先确认SAT避免空域伪证明。
fn term(value: &Val<B64>) -> Exp<Sym> {
    match value {
        Val::Bits(bits) => Exp::Bits64(*bits),
        Val::Symbolic(symbol) => Exp::Var(*symbol),
        _ => panic!("探针必须返回位串"),
    }
}

fn main() {
    configure_tastic(Tactic::Qfaufbv);
    let args: Vec<String> = std::env::args().collect();
    assert_eq!(args.len(), 3, "用法: probe IR FUNCTION");
    let ir = std::fs::read_to_string(&args[1]).unwrap();
    let mut symtab = Symtab::new();
    let mut defs = IrParser::new()
        .parse(&mut symtab, new_ir_lexer(&ir))
        .unwrap();
    let type_info = IRTypeInfo::new(&defs);
    let state = initialize_architecture(
        &mut defs,
        symtab,
        type_info,
        &empty_config(),
        AssertionMode::Optimistic,
        false,
    );
    let paths = Mutex::new(0usize);
    execute_ir_function(
        &args[2],
        &[],
        &state.shared_state,
        &state.regs,
        &state.lets,
        &paths,
        &|_, _, result, shared, mut solver, paths| {
            let value = match result {
                Ok((Run::Finished(value), _)) => value,
                Ok(_) => panic!("执行未完成"),
                Err((error, _)) => panic!("执行失败: {error:?}"),
            };
            let Val::Struct(fields) = value else {
                panic!("预期元组")
            };
            let mut fields: Vec<_> = fields.iter().collect();
            fields.sort_by_key(|(name, _)| shared.symtab.to_str(**name));
            assert!(fields.len() == 2 || fields.len() == 4);
            let half = fields.len() / 2;
            let differs = (0..half)
                .map(|i| {
                    Exp::Neq(
                        Box::new(term(fields[i].1)),
                        Box::new(term(fields[i + half].1)),
                    )
                })
                .reduce(|a, b| Exp::Or(Box::new(a), Box::new(b)))
                .unwrap();
            assert_eq!(
                solver.check_sat(SourceLoc::unknown()),
                SmtResult::Sat,
                "完成域必须非空"
            );
            assert_eq!(
                solver.check_sat_with(&differs, SourceLoc::unknown()),
                SmtResult::Unsat,
                "旧新完整flags或bits可不同"
            );
            *paths.lock().unwrap() += 1;
        },
    );
    assert_eq!(*paths.lock().unwrap(), 1, "必须唯一完成路径");
    println!(
        "{} SAT, old/new flags+bits difference UNSAT, paths=1",
        args[2]
    );
}
