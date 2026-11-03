use isla_lib::bitvector::b64::B64;
use isla_lib::bitvector::BV;
use isla_lib::config::{ISAConfig, Tool};
use isla_lib::executor::{execute_ir_function_with_checkpoint, Run};
use isla_lib::init::initialize_architecture;
use isla_lib::ir::{AssertionMode, IRTypeInfo, Name, Symtab, Val};
use isla_lib::ir_lexer::new_ir_lexer;
use isla_lib::ir_parser::IrParser;
use isla_lib::smt::smtlib::{Exp, Ty};
use isla_lib::smt::{checkpoint, configure_tastic, Config, Context, SmtResult, Solver, Tactic};
use isla_lib::source_loc::SourceLoc;
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::Mutex;

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

fn empty_tool() -> Tool { Tool { executable: PathBuf::new(), options: Vec::new() } }

#[derive(Clone, Copy)]
enum Expected { True, False, MatchFailure, Assertion }
#[derive(Clone, Copy, Debug)]
enum Input { Bits(Option<u32>), Int(Option<i64>), None }

fn main() {
    configure_tastic(Tactic::Qfaufbv);
    let args: Vec<_> = std::env::args().collect();
    assert_eq!(args.len(), 3, "runner FIXTURE_IR e|non_e");
    let e_mode = match args[2].as_str() { "e" => true, "non_e" => false, _ => panic!("bad mode") };
    let ir = Box::leak(std::fs::read_to_string(&args[1]).unwrap().into_boxed_str());
    let mut symtab = Symtab::new();
    let definitions = IrParser::new().parse(&mut symtab, new_ir_lexer(ir)).unwrap();
    let type_info = IRTypeInfo::new(&definitions);
    let definitions = Box::leak(definitions.into_boxed_slice());
    let state = initialize_architecture(definitions, symtab, type_info, &empty_config(), AssertionMode::Optimistic, false);
    let info = SourceLoc::unknown();

    let run = |name: &str, input: Input, expected: Expected| {
        let context = Context::new(Config::new());
        let mut solver = Solver::<B64>::new(&context);
        let args: Vec<_> = match input {
            Input::Bits(Some(word)) => vec![Val::Bits(B64::new(u64::from(word), 32))],
            Input::Bits(None) => vec![Val::Symbolic(solver.declare_const(Ty::BitVec(32), info))],
            Input::Int(Some(value)) => vec![Val::I64(value)],
            Input::Int(None) => vec![Val::Symbolic(solver.declare_const(Ty::BitVec(64), info))],
            Input::None => vec![],
        };
        let paths = Mutex::new(0usize);
        let ir_name = if name.contains("size") { name.replace("size", "sizze") } else { name.to_string() };
        execute_ir_function_with_checkpoint(
            &format!("z{ir_name}"), &args, &state.shared_state, &state.regs, &state.lets,
            &paths, &|_, _, result, _, mut solver, paths| {
                *paths.lock().unwrap() += 1;
                assert_eq!(solver.check_sat(info), SmtResult::Sat, "{name}: dead path");
                match (result, expected) {
                    (Err((error, _)), Expected::MatchFailure) =>
                        assert!(format!("{error:?}").contains("MatchFailure"), "{name}: {error:?}"),
                    (Err((error, _)), Expected::Assertion) =>
                        assert!(format!("{error:?}").contains("Assertion"), "{name}: {error:?}"),
                    (Ok((Run::Finished(value), frame)), Expected::True | Expected::False) => {
                        assert!(!frame.has_sampled_branch(), "{name}: sampled branch");
                        let wanted = matches!(expected, Expected::True);
                        match value {
                            Val::Bool(actual) => assert_eq!(actual, wanted, "{name}"),
                            Val::Symbolic(sym) => {
                                let difference = if wanted { Exp::Not(Box::new(Exp::Var(sym))) }
                                                 else { Exp::Var(sym) };
                                assert_eq!(solver.check_sat_with(&difference, info), SmtResult::Unsat,
                                           "{name}: difference SAT");
                            }
                            other => panic!("{name}: expected Bool, got {other:?}"),
                        }
                    }
                    (Err((error, _)), _) => panic!("{name}: unexpected {error:?}"),
                    _ => panic!("{name}: unexpected state"),
                }
            }, checkpoint(&mut solver), None,
        );
        let count = *paths.lock().unwrap();
        assert!(count > 0, "{name}: no paths");
        println!("PASS {name} {input:?} paths={count}");
    };

    for name in ["equal_matches", "equal_decode", "equal_roundtrip", "forward_matches_from_word"] {
        run(name, Input::Bits(None), Expected::True);
    }
    run("other_forward_matches", Input::None, Expected::True);
    for name in ["equal_size_encode", "equal_size_matches"] {
        run(name, Input::Int(None), Expected::True);
    }
    for size in [-1, 0, 1, 2, 3, 4, 8, 16, 17, i64::MAX] {
        for name in ["old_size_matches", "new_size_matches"] {
            run(name, Input::Int(Some(size)), Expected::True);
        }
        run("equal_size_encode", Input::Int(Some(size)), Expected::True);
    }
    let ops = [1u32, 0, 4, 12, 8, 16, 20, 24, 28, 5];
    let registers = if e_mode { [0u32, 3, 15] } else { [0u32, 17, 31] };
    for (i, op) in ops.into_iter().enumerate() {
        for width in 0u32..5 {
            let rs2 = registers[i % 3];
            let rs1 = registers[(i + 1) % 3];
            let rd = registers[(i + 2) % 3];
            let word = (op << 27) | (((i as u32) & 1) << 26) | ((width & 1) << 25)
                | (rs2 << 20) | (rs1 << 15) | (width << 12) | (rd << 7) | 0x2f;
            run("equal_decode", Input::Bits(Some(word)), Expected::True);
            run("equal_roundtrip", Input::Bits(Some(word)), Expected::True);
            run("forward_matches_from_word", Input::Bits(Some(word)), Expected::True);
        }
    }
    let valid = (5u32 << 27) | (3 << 20) | (1 << 15) | (4 << 12) | (3 << 7) | 0x2f;
    for word in [valid ^ 1, valid ^ (1 << 28), valid | (7 << 12)] {
        run("amo_value", Input::Bits(Some(word)), Expected::MatchFailure);
    }
    if e_mode {
        for word in [valid | (16 << 20), valid | (16 << 15), valid | (16 << 7)] {
            run("amo_value", Input::Bits(Some(word)), Expected::MatchFailure);
        }
    }
    run("opcode_fatal_negative", Input::Bits(Some(valid ^ 1)), Expected::False);
    run("opcode_fatal_negative", Input::Bits(Some(valid)), Expected::Assertion);
    let guard_false = (5u32 << 27) | (3 << 20) | (1 << 15) | (3 << 7) | 0x2f;
    let guard_true = guard_false | (2 << 12);
    for name in ["old_guarded_matches", "new_guarded_matches"] {
        run(name, Input::Bits(Some(valid ^ 1)), Expected::False);
        run(name, Input::Bits(Some(guard_false)), Expected::False);
        run(name, Input::Bits(Some(guard_true)), Expected::True);
        run(name, Input::Bits(Some(valid)), Expected::Assertion);
    }
    for size in [2i64, 3, 4, 8, 17] {
        run("equal_guarded_forward", Input::Int(Some(size)), Expected::True);
    }
    for name in ["old_guarded_forward", "new_guarded_forward"] {
        run(name, Input::Int(Some(1)), Expected::MatchFailure);
        run(name, Input::Int(Some(16)), Expected::Assertion);
    }
}
