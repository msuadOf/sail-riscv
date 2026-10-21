// Prove old/new full Bool results and unchanged vtype for arbitrary raw inputs.
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

fn empty_config() -> ISAConfig<B64> {
    ISAConfig {
        pc: Name::from_u32(u32::MAX),
        register_event_sets: HashMap::new(),
        assembler: Tool { executable: PathBuf::new(), options: Vec::new() },
        objdump: Tool { executable: PathBuf::new(), options: Vec::new() },
        nm: Tool { executable: PathBuf::new(), options: Vec::new() },
        linker: Tool { executable: PathBuf::new(), options: Vec::new() },
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

fn term(value: &Val<B64>) -> Exp<Sym> {
    match value {
        Val::Bool(b) => Exp::Bool(*b),
        Val::Bits(b) => Exp::Bits64(*b),
        Val::Symbolic(s) => Exp::Var(*s),
        other => panic!("unexpected result value: {other:?}"),
    }
}

fn main() {
    configure_tastic(Tactic::Qfaufbv);
    let args: Vec<_> = std::env::args().collect();
    assert_eq!(args.len(), 2, "usage: runner SMALL_IR");
    let ir = std::fs::read_to_string(&args[1]).unwrap();
    let mut symtab = Symtab::new();
    let mut definitions = IrParser::new()
        .parse(&mut symtab, new_ir_lexer(&ir))
        .unwrap();
    let type_info = IRTypeInfo::new(&definitions);
    let state = initialize_architecture(
        &mut definitions,
        symtab,
        type_info,
        &empty_config(),
        AssertionMode::Optimistic,
        false,
    );
    for sew in [8, 16, 32, 64] {
        let name = format!("zproof_sew{sew}");
        let paths = Mutex::new(0usize);
        execute_ir_function(
            &name,
            &[Val::Unit],
            &state.shared_state,
            &state.regs,
            &state.lets,
            &paths,
            &|_, _, result, shared, mut solver, paths| {
                let (value, frame) = match result {
                    Ok((Run::Finished(value), frame)) => (value, frame),
                    _ => panic!("{name}: incomplete or failed path"),
                };
                assert!(!frame.has_sampled_branch(), "{name}: sampled path");
                let Val::Struct(fields) = value else { panic!("{name}: expected tuple") };
                let mut fields: Vec<_> = fields.iter().collect();
                fields.sort_by_key(|(key, _)| shared.symtab.to_str(**key));
                assert_eq!(fields.len(), 10, "{name}: result shape");
                assert_eq!(solver.check_sat(SourceLoc::unknown()), SmtResult::Sat,
                           "{name}: empty completed path");
                for i in 0..4 {
                    let differs = Exp::Neq(Box::new(term(fields[i].1)),
                                           Box::new(term(fields[i + 4].1)));
                    assert_eq!(solver.check_sat_with(&differs, SourceLoc::unknown()),
                               SmtResult::Unsat, "{name}: Bool result {i} differs");
                }
                let state_differs = Exp::Neq(Box::new(term(fields[8].1)),
                                             Box::new(term(fields[9].1)));
                assert_eq!(solver.check_sat_with(&state_differs, SourceLoc::unknown()),
                           SmtResult::Unsat, "{name}: helper changed vtype");
                *paths.lock().unwrap() += 1;
            },
        );
        let count = *paths.lock().unwrap();
        assert!(count > 0, "{name}: no completed path");
        println!("PASS {name}: {count} SAT paths; four full Bool differences UNSAT; state difference UNSAT");
    }
}
