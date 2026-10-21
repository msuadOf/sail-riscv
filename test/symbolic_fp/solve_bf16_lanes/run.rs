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
    let tool = || Tool { executable: PathBuf::new(), options: Vec::new() };
    ISAConfig {
        pc: Name::from_u32(u32::MAX), register_event_sets: HashMap::new(),
        assembler: tool(), objdump: tool(), nm: tool(), linker: tool(),
        page_table_base: 0, page_size: 0, s2_page_table_base: 0, s2_page_size: 0,
        default_page_table_setup: String::new(), thread_base: 0, thread_top: 0,
        thread_stride: 0, symbolic_addr_base: 0, symbolic_addr_top: 0,
        symbolic_addr_stride: 0, default_registers: HashMap::new(),
        reset_registers: Vec::new(), reset_constraints: Vec::new(),
        const_primops: HashMap::new(), function_assumptions: Vec::new(),
        register_renames: HashMap::new(), ignored_registers: HashSet::new(),
        relaxed_registers: HashSet::new(), probes: HashSet::new(),
        probe_functions: HashSet::new(), trace_functions: HashSet::new(),
        translation_function: None, in_program_order: HashSet::new(),
        default_sizeof: 0, zero_announce_exit: false, memory_regions: None,
        page_table_config: None, pmp: None, clint_enabled: None,
        execution_limits: None,
    }
}

fn fields<'a>(value: &'a Val<B64>, symtab: &Symtab) -> Vec<&'a Val<B64>> {
    let Val::Struct(items) = value else { panic!("expected tuple") };
    let mut items: Vec<_> = items.iter().collect();
    items.sort_by_key(|(name, _)| symtab.to_str(**name));
    items.into_iter().map(|(_, value)| value).collect()
}

fn term(value: &Val<B64>) -> Exp<Sym> {
    match value {
        Val::Symbolic(symbol) => Exp::Var(*symbol),
        Val::Bits(bits) => Exp::Bits64(*bits),
        other => panic!("unexpected value: {other:?}"),
    }
}

fn unequal(a: &Val<B64>, b: &Val<B64>) -> Exp<Sym> {
    Exp::Neq(Box::new(term(a)), Box::new(term(b)))
}

fn main() {
    configure_tastic(Tactic::Qfaufbv);
    let ir_file = std::env::args().nth(1).expect("usage: run IR_FILE");
    let ir = Box::leak(std::fs::read_to_string(ir_file).unwrap().into_boxed_str());
    let mut symtab = Symtab::new();
    let definitions = IrParser::new().parse(&mut symtab, new_ir_lexer(ir)).unwrap();
    let type_info = IRTypeInfo::new(&definitions);
    let definitions = Box::leak(definitions.into_boxed_slice());
    let state = initialize_architecture(definitions, symtab, type_info, &empty_config(), AssertionMode::Optimistic, false);

    let paths = Mutex::new(0usize);
    execute_ir_function(
        "zbf16_unknown_equivalence", &[], &state.shared_state, &state.regs,
        &state.lets, &paths, &|_, _, result, shared, mut solver, paths| {
            *paths.lock().unwrap() += 1;
            let Ok((Run::Finished(value), _)) = result else { panic!("equivalence did not finish") };
            let tuple = fields(&value, &shared.symtab);
            assert_eq!(tuple.len(), 5);
            assert_eq!(solver.check_sat(SourceLoc::unknown()), SmtResult::Sat);
            let difference = Exp::Or(
                Box::new(unequal(tuple[1], tuple[3])),
                Box::new(unequal(tuple[2], tuple[4])),
            );
            assert_eq!(solver.check_sat_with(&difference, SourceLoc::unknown()), SmtResult::Unsat);
        },
    );
    let equivalence_paths = *paths.lock().unwrap();
    assert!(equivalence_paths > 0);

    let new_paths = Mutex::new(0usize);
    execute_ir_function(
        "zbf16_unknown_new", &[], &state.shared_state, &state.regs,
        &state.lets, &new_paths, &|_, _, result, _, mut solver, paths| {
            *paths.lock().unwrap() += 1;
            assert!(matches!(result, Ok((Run::Finished(_), _))));
            assert_eq!(solver.check_sat(SourceLoc::unknown()), SmtResult::Sat);
        },
    );
    assert_eq!(*new_paths.lock().unwrap(), 1, "new conversion forked");
    println!("BF16 unknown input: {equivalence_paths} old/new paths SAT and difference UNSAT; new path count 1 SAT");
}
