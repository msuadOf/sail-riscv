use isla_lib::bitvector::b64::B64;
use isla_lib::bitvector::BV;
use isla_lib::config::{ISAConfig, Tool};
use isla_lib::executor::{execute_ir_function_with_checkpoint, Run};
use isla_lib::init::initialize_architecture;
use isla_lib::ir::{AssertionMode, IRTypeInfo, Name, Symtab, Val};
use isla_lib::ir_lexer::new_ir_lexer;
use isla_lib::ir_parser::IrParser;
use isla_lib::smt::smtlib::{Exp, Ty};
use isla_lib::smt::{checkpoint, configure_tastic, Config, Context, Event, SmtResult, Solver, Tactic};
use isla_lib::source_loc::SourceLoc;
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::Mutex;

fn empty_tool() -> Tool {
    Tool { executable: PathBuf::new(), options: Vec::new() }
}

fn empty_config() -> ISAConfig<B64> {
    ISAConfig {
        pc: Name::from_u32(u32::MAX), register_event_sets: HashMap::new(),
        assembler: empty_tool(), objdump: empty_tool(), nm: empty_tool(), linker: empty_tool(),
        page_table_base: 0, page_size: 0, s2_page_table_base: 0, s2_page_size: 0,
        default_page_table_setup: String::new(), thread_base: 0, thread_top: 0, thread_stride: 0,
        symbolic_addr_base: 0, symbolic_addr_top: 0, symbolic_addr_stride: 0,
        default_registers: HashMap::new(), reset_registers: Vec::new(), reset_constraints: Vec::new(),
        const_primops: HashMap::new(), function_assumptions: Vec::new(),
        register_renames: HashMap::new(), ignored_registers: HashSet::new(),
        relaxed_registers: HashSet::new(), probes: HashSet::new(), probe_functions: HashSet::new(),
        trace_functions: HashSet::new(), translation_function: None, in_program_order: HashSet::new(),
        default_sizeof: 0, zero_announce_exit: false, memory_regions: None,
        page_table_config: None, pmp: None, clint_enabled: None, execution_limits: None,
    }
}

fn main() {
    configure_tastic(Tactic::Qfaufbv);
    let args: Vec<_> = std::env::args().collect();
    assert_eq!(args.len(), 2, "negate_runner FIXTURE_IR");
    let ir = Box::leak(std::fs::read_to_string(&args[1]).unwrap().into_boxed_str());
    let mut symtab = Symtab::new();
    let definitions = IrParser::new().parse(&mut symtab, new_ir_lexer(ir)).unwrap();
    let type_info = IRTypeInfo::new(&definitions);
    let definitions = Box::leak(definitions.into_boxed_slice());
    let state = initialize_architecture(definitions, symtab, type_info, &empty_config(), AssertionMode::Optimistic, false);
    let info = SourceLoc::unknown();

    let run = |name: &str, width: u32, concrete: Option<u64>, paths_expected: usize,
               expected_bool: Option<bool>, expected_bits: Option<u64>| {
        let context = Context::new(Config::new());
        let mut solver = Solver::<B64>::new(&context);
        let argument = match concrete {
            Some(value) => Val::Bits(B64::new(value, width)),
            None => Val::Symbolic(solver.declare_const(Ty::BitVec(width), info)),
        };
        let paths = Mutex::new(0usize);
        execute_ir_function_with_checkpoint(
            &format!("z{name}"), &[argument], &state.shared_state, &state.regs, &state.lets,
            &paths, &|_, _, result, _, mut solver, paths| {
                *paths.lock().unwrap() += 1;
                assert!(!solver.trace().to_vec().iter().any(|event| matches!(event,
                    Event::ReadReg(..) | Event::WriteReg(..) | Event::ReadMem { .. }
                    | Event::WriteMem { .. } | Event::Abstract { .. })), "{name}: impure trace");
                assert_eq!(solver.check_sat(info), SmtResult::Sat, "{name}: dead/unknown path");
                match result {
                    Ok((Run::Finished(value), frame)) => {
                        assert!(!frame.has_sampled_branch(), "{name}: sampled branch");
                        if let Some(expected) = expected_bool {
                            match value {
                                Val::Bool(actual) => assert_eq!(actual, expected, "{name}"),
                                Val::Symbolic(sym) => {
                                    let difference = if expected { Exp::Not(Box::new(Exp::Var(sym))) }
                                                     else { Exp::Var(sym) };
                                    assert_eq!(solver.check_sat_with(&difference, info), SmtResult::Unsat,
                                        "{name}: Boolean difference is SAT");
                                }
                                other => panic!("{name}: expected Bool, got {other:?}"),
                            }
                        }
                        if let Some(expected) = expected_bits {
                            assert_eq!(value, Val::Bits(B64::new(expected, width)), "{name}: result bits");
                        }
                    }
                    Err((error, _)) => panic!("{name}: unexpected {error:?}"),
                    _ => panic!("{name}: unexpected run state"),
                }
            }, checkpoint(&mut solver), None,
        );
        let actual = *paths.lock().unwrap();
        assert_eq!(actual, paths_expected, "{name}: path count");
        println!("PASS {name} width={width} input={concrete:?} paths={actual}");
    };

    for (suffix, width, nan, snan) in [
        ("H", 16, 0x7e31_u64, 0x7c31_u64),
        ("S", 32, 0x7fc12345_u64, 0x7f812345_u64),
        ("D", 64, 0x7ff8000000001234_u64, 0x7ff0000000001234_u64),
    ] {
        let sign = 1_u64 << (width - 1);
        run(&format!("equal_{suffix}"), width, None, 2, Some(true), None);
        run(&format!("raw_flip_{suffix}"), width, None, 1, Some(true), None);
        run(&format!("old_negate_{suffix}"), width, None, 2, None, None);
        run(&format!("new_negate_{suffix}"), width, None, 1, None, None);
        for input in [0, sign, nan, nan | sign, snan, snan | sign, 1, sign | 1] {
            for stem in ["old_negate", "new_negate"] {
                run(&format!("{stem}_{suffix}"), width, Some(input), 1, None, Some(input ^ sign));
            }
        }
    }
}
