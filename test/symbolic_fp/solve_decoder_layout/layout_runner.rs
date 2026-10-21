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

#[derive(Clone, Copy)]
enum Input { Bits(u32, Option<u64>), Int(i64), SymbolicInt }
#[derive(Clone, Copy)]
enum Expect { Bool(bool), Bits(u32, u64), Failure, Any }

fn main() {
    configure_tastic(Tactic::Qfaufbv);
    let args: Vec<_> = std::env::args().collect();
    assert_eq!(args.len(), 2, "layout_runner FIXTURE_IR");
    let ir = Box::leak(std::fs::read_to_string(&args[1]).unwrap().into_boxed_str());
    let mut symtab = Symtab::new();
    let definitions = IrParser::new().parse(&mut symtab, new_ir_lexer(ir)).unwrap();
    let type_info = IRTypeInfo::new(&definitions);
    let definitions = Box::leak(definitions.into_boxed_slice());
    let state = initialize_architecture(definitions, symtab, type_info, &empty_config(), AssertionMode::Optimistic, false);
    let info = SourceLoc::unknown();

    let run = |name: &str, input: Input, expect: Expect, paths_expected: Option<usize>| {
        let context = Context::new(Config::new());
        let mut solver = Solver::<B64>::new(&context);
        let argument = match input {
            Input::Bits(width, Some(value)) => Val::Bits(B64::new(value, width)),
            Input::Bits(width, None) => Val::Symbolic(solver.declare_const(Ty::BitVec(width), info)),
            Input::Int(value) => Val::I64(value),
            Input::SymbolicInt => Val::Symbolic(solver.declare_const(Ty::BitVec(64), info)),
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
                match (result, expect) {
                    (Err((error, _)), Expect::Failure) =>
                        assert!(format!("{error:?}").contains("MatchFailure"), "{name}: {error:?}"),
                    (Ok((Run::Finished(value), frame)), expected) => {
                        assert!(!frame.has_sampled_branch(), "{name}: sampled branch");
                        match expected {
                            Expect::Bool(expected) => match value {
                                Val::Bool(actual) => assert_eq!(actual, expected, "{name}"),
                                Val::Symbolic(sym) => {
                                    let difference = if expected { Exp::Not(Box::new(Exp::Var(sym))) }
                                                     else { Exp::Var(sym) };
                                    assert_eq!(solver.check_sat_with(&difference, info), SmtResult::Unsat,
                                        "{name}: Boolean difference is SAT");
                                }
                                other => panic!("{name}: expected Bool, got {other:?}"),
                            },
                            Expect::Bits(width, expected) =>
                                assert_eq!(value, Val::Bits(B64::new(expected, width)), "{name}: result bits"),
                            Expect::Any => (),
                            Expect::Failure => panic!("{name}: expected MatchFailure"),
                        }
                    }
                    (Err((error, _)), _) => panic!("{name}: unexpected {error:?}"),
                    _ => panic!("{name}: unexpected run state"),
                }
            }, checkpoint(&mut solver), None,
        );
        let actual = *paths.lock().unwrap();
        assert!(actual > 0, "{name}: no completed paths");
        if let Some(expected) = paths_expected { assert_eq!(actual, expected, "{name}: path count"); }
        println!("PASS {name} input={} paths={actual}", match input {
            Input::Bits(_, Some(value)) => format!("0x{value:x}"),
            Input::Bits(_, None) => "unknown".to_string(),
            Input::Int(value) => value.to_string(),
            Input::SymbolicInt => "unknown-i64".to_string(),
        });
    };

    run("equal_decode", Input::Bits(32, None), Expect::Bool(true), None);
    run("equal_raw_nreg", Input::SymbolicInt, Expect::Bool(true), None);
    for name in ["old_vmvr_bad_funct3", "new_vmvr_bad_funct3",
                 "old_vext_bad_funct3", "new_vext_bad_funct3"] {
        run(name, Input::Bits(5, None), Expect::Any,
            if name.starts_with("new") { Some(1) } else { None });
    }
    let opcode = 0x57_u64;
    let vs2 = 2_u64;
    let vd = 3_u64;
    for (nreg_bits, nreg) in [(0_u64, 1_i64), (1, 2), (3, 4), (7, 8)] {
        let word = (0b100111_u64 << 26) | (1 << 25) | (vs2 << 20) |
                   (nreg_bits << 15) | (0b011 << 12) | (vd << 7) | opcode;
        run("equal_decode", Input::Bits(32, Some(word)), Expect::Bool(true), Some(1));
        run(&format!("expect_vmvr_{nreg}"), Input::Bits(32, Some(word)), Expect::Bool(true), Some(1));
        for name in ["old_encode_vmvr", "new_encode_vmvr"] {
            run(name, Input::Int(nreg), Expect::Bits(32, word), Some(1));
        }
    }
    for (bits, vm, member) in [(2_u64, 0_u64, "VEXT8_ZVF8"), (3, 1, "VEXT8_SVF8"),
                                (4, 0, "VEXT4_ZVF4"), (5, 1, "VEXT4_SVF4"),
                                (6, 0, "VEXT2_ZVF2"), (7, 1, "VEXT2_SVF2")] {
        let word = (0b010010_u64 << 26) | (vm << 25) | (vs2 << 20) |
                   (bits << 15) | (0b010 << 12) | (vd << 7) | opcode;
        run("equal_decode", Input::Bits(32, Some(word)), Expect::Bool(true), Some(1));
        run(&format!("expect_vext_{member}"), Input::Bits(32, Some(word)), Expect::Bool(true), Some(1));
    }
    for raw in [0_i64, 1, 2, 3, 4, 7, 8, 9, -1] {
        for name in ["old_encode_vmvr_matches", "new_encode_vmvr_matches"] {
            run(name, Input::Int(raw), Expect::Bool(true), Some(1));
        }
        let bits = match raw { 1 => 0, 2 => 1, 4 => 3, _ => 7 };
        let word = (0b100111_u64 << 26) | (1 << 25) | (vs2 << 20) |
                   (bits << 15) | (0b011 << 12) | (vd << 7) | opcode;
        for name in ["old_encode_vmvr", "new_encode_vmvr"] {
            run(name, Input::Int(raw), Expect::Bits(32, word), Some(1));
        }
    }
    let valid_vmvr = (0b100111_u64 << 26) | (1 << 25) | (vs2 << 20) | (0b011 << 12) | (vd << 7) | opcode;
    let valid_vext = (0b010010_u64 << 26) | (vs2 << 20) | (2 << 15) | (0b010 << 12) | (vd << 7) | opcode;
    for word in [
        valid_vmvr ^ (1 << 25), valid_vmvr ^ (1 << 26), valid_vmvr ^ (1 << 12),
        valid_vmvr ^ 1, valid_vmvr | (2 << 15),
        valid_vext ^ (1 << 26), valid_vext ^ (1 << 12), valid_vext ^ 1,
        valid_vext ^ (2 << 15),
    ] {
        run("equal_decode", Input::Bits(32, Some(word)), Expect::Bool(true), Some(1));
        for name in ["old_top_backwards", "new_top_backwards"] {
            run(name, Input::Bits(32, Some(word)), Expect::Failure, Some(1));
        }
    }
    for word in [valid_vmvr ^ (1 << 25), valid_vmvr ^ (1 << 12), valid_vmvr | (2 << 15)] {
        run("vmvr_layout_backwards", Input::Bits(32, Some(word)), Expect::Failure, Some(1));
    }
    for word in [valid_vext ^ (1 << 26), valid_vext ^ (1 << 12), valid_vext ^ (2 << 15)] {
        run("vext_layout_backwards", Input::Bits(32, Some(word)), Expect::Failure, Some(1));
    }
}
