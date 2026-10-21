use isla_lib::bitvector::b64::B64;
use isla_lib::bitvector::BV;
use isla_lib::config::{ISAConfig, Tool};
use isla_lib::executor::{execute_ir_function_with_checkpoint, Run};
use isla_lib::init::initialize_architecture;
use isla_lib::ir::{AssertionMode, IRTypeInfo, Name, Symtab, Val};
use isla_lib::ir_lexer::new_ir_lexer;
use isla_lib::ir_parser::IrParser;
use isla_lib::smt::smtlib::{Exp, Ty};
use isla_lib::smt::{checkpoint, configure_tastic, Config, Context, EnumId, EnumMember, Event, SmtResult, Solver, Tactic};
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
    assert_eq!(args.len(), 2, "runner FIXTURE_IR");
    let ir = Box::leak(std::fs::read_to_string(&args[1]).unwrap().into_boxed_str());
    let mut symtab = Symtab::new();
    let definitions = IrParser::new().parse(&mut symtab, new_ir_lexer(ir)).unwrap();
    let type_info = IRTypeInfo::new(&definitions);
    let definitions = Box::leak(definitions.into_boxed_slice());
    let state = initialize_architecture(definitions, symtab, type_info, &empty_config(), AssertionMode::Optimistic, false);
    let info = SourceLoc::unknown();

    let run = |name: &str, width: Option<u32>, concrete: Option<u64>, expected: Option<bool>,
               expect_failure: bool, expected_paths: usize, expected_value: Option<Val<B64>>| {
        let context = Context::new(Config::new());
        let mut solver = Solver::<B64>::new(&context);
        let arguments = match width {
            None => Vec::new(),
            Some(0) => vec![Val::Enum(EnumMember {
                enum_id: EnumId::from_name(state.shared_state.symtab.lookup("zvextfunct6")),
                member: concrete.unwrap() as usize,
            })],
            Some(64) => vec![Val::I64(concrete.unwrap() as i64)],
            Some(width) => vec![match concrete {
                Some(value) => Val::Bits(B64::new(value, width)),
                None => Val::Symbolic(solver.declare_const(Ty::BitVec(width), info)),
            }],
        };
        let paths = Mutex::new(0usize);
        execute_ir_function_with_checkpoint(
            &format!("z{name}"), &arguments, &state.shared_state, &state.regs, &state.lets,
            &paths, &|_, _, result, _, mut solver, paths| {
                *paths.lock().unwrap() += 1;
                let events = solver.trace().to_vec();
                assert!(!events.iter().any(|event| matches!(event,
                    Event::ReadReg(..) | Event::WriteReg(..) | Event::ReadMem { .. }
                    | Event::WriteMem { .. } | Event::Abstract { .. })), "{name}: impure trace");
                assert_eq!(solver.check_sat(info), SmtResult::Sat, "{name}: dead/unknown path");
                match result {
                    Err((error, _)) if expect_failure => {
                        assert!(format!("{error:?}").contains("MatchFailure"), "{name}: {error:?}");
                    }
                    Ok((Run::Finished(value), frame)) if !expect_failure => {
                        assert!(!frame.has_sampled_branch(), "{name}: sampled branch");
                        if let Some(expected) = expected {
                            match &value {
                                Val::Bool(value) => assert_eq!(*value, expected, "{name}"),
                                Val::Symbolic(sym) => {
                                    let mismatch = if expected { Exp::Not(Box::new(Exp::Var(*sym))) }
                                                   else { Exp::Var(*sym) };
                                    assert_eq!(solver.check_sat_with(&mismatch, info), SmtResult::Unsat,
                                        "{name}: Boolean difference is SAT");
                                }
                                other => panic!("{name}: expected bool, got {other:?}"),
                            }
                        }
                        if let Some(expected_value) = &expected_value {
                            assert_eq!(&value, expected_value, "{name}: value differs");
                        }
                    }
                    Err((error, _)) => panic!("{name}: unexpected {error:?}"),
                    _ => panic!("{name}: unexpected run state"),
                }
            }, checkpoint(&mut solver), None,
        );
        let actual_paths = *paths.lock().unwrap();
        assert!(actual_paths > 0, "{name}: no completed paths");
        if expected_paths > 0 { assert_eq!(actual_paths, expected_paths, "{name}: path count"); }
        println!("PASS {name} width={width:?} concrete={concrete:?} paths={actual_paths} failure={expect_failure}");
    };

    for value in 0..32 {
        let nreg = matches!(value, 0 | 1 | 3 | 7);
        let vext = matches!(value, 2 | 3 | 4 | 5 | 6 | 7);
        for prefix in ["old", "new"] {
            run(&format!("{prefix}_encdec_nreg_forwards_matches"), Some(5), Some(value), Some(nreg), false, 1, None);
            run(&format!("{prefix}_vext_vs1_backwards_matches"), Some(5), Some(value), Some(vext), false, 1, None);
        }
        if !nreg {
            for prefix in ["old", "new"] {
                run(&format!("{prefix}_encdec_nreg_forwards"), Some(5), Some(value), None, true, 1, None);
            }
        }
        if !vext {
            for prefix in ["old", "new"] {
                run(&format!("{prefix}_vext_vs1_backwards"), Some(5), Some(value), None, true, 1, None);
            }
        }
    }
    for (bits, nreg) in [(0, 1), (1, 2), (3, 4), (7, 8)] {
        for prefix in ["old", "new"] {
            run(&format!("{prefix}_encdec_nreg_forwards"), Some(5), Some(bits), None, false, 1,
                Some(Val::I64(nreg)));
            run(&format!("{prefix}_encdec_nreg_backwards"), Some(64), Some(nreg as u64), None,
                false, 1, Some(Val::Bits(B64::new(bits, 5))));
        }
        run(&format!("nreg_roundtrip_{bits:05b}"), None, None, None, false, 1,
            Some(Val::Bits(B64::new(bits, 5))));
    }
    let enum_id = EnumId::from_name(state.shared_state.symtab.lookup("zvextfunct6"));
    for (member, bits, name) in [(0, 6, "VEXT2_ZVF2"), (1, 7, "VEXT2_SVF2"),
                                 (2, 4, "VEXT4_ZVF4"), (3, 5, "VEXT4_SVF4"),
                                 (4, 2, "VEXT8_ZVF8"), (5, 3, "VEXT8_SVF8")] {
        let variant = Val::Enum(EnumMember { enum_id, member });
        for prefix in ["old", "new"] {
            run(&format!("{prefix}_vext_vs1_forwards"), Some(0), Some(member as u64), None,
                false, 1, Some(Val::Bits(B64::new(bits, 5))));
            run(&format!("{prefix}_vext_vs1_backwards"), Some(5), Some(bits), None, false, 1,
                Some(variant.clone()));
        }
        run(&format!("vext_roundtrip_{name}"), None, None, None, false, 1,
            Some(variant));
    }
    for (name, paths) in [("old_encdec_nreg_forwards_matches", 5),
                          ("new_encdec_nreg_forwards_matches", 1),
                          ("old_vext_vs1_backwards_matches", 7),
                          ("new_vext_vs1_backwards_matches", 1)] {
        run(name, Some(5), None, None, false, paths, None);
    }
    for name in ["equal_nreg_matches", "equal_vext_matches"] {
        run(name, Some(5), None, Some(true), false,
            if name == "equal_nreg_matches" { 5 } else { 7 }, None);
    }
    run("equal_decode", Some(32), None, Some(true), false, 0, None);
    run("equal_decode16", Some(16), None, Some(true), false, 0, None);
}
