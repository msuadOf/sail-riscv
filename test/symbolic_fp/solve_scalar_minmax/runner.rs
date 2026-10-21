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
use isla_lib::smt::{configure_tastic, Event, SmtResult, Tactic};
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

use std::io::Write;

fn main() {
    configure_tastic(Tactic::Qfaufbv);
    let args: Vec<String> = std::env::args().collect();
    assert_eq!(args.len(), 3, "usage: vector_helper_runner IR NAMES");
    let ir = Box::leak(std::fs::read_to_string(&args[1]).unwrap().into_boxed_str());
    let mut symtab = Symtab::new();
    let definitions = IrParser::new()
        .parse(&mut symtab, new_ir_lexer(ir))
        .expect("parse D IR");
    let type_info = IRTypeInfo::new(&definitions);
    let definitions = Box::leak(definitions.into_boxed_slice());
    let config = empty_config();
    let names = std::fs::read_to_string(&args[2]).unwrap();
    let names: Vec<_> = names.lines().filter(|name| !name.is_empty()).collect();
    let state = initialize_architecture(
        definitions,
        symtab,
        type_info,
        &config,
        AssertionMode::Optimistic,
        false,
    );
    for (index, name) in names.iter().enumerate() {
        let wrapper = format!("z{name}");
        let paths = Mutex::new(0usize);
        execute_ir_function(
            &wrapper,
            &[Val::Unit],
            &state.shared_state,
            &state.regs,
            &state.lets,
            &paths,
            &|_, _, result, _, mut solver, paths| {
                *paths.lock().unwrap() += 1;
                let Ok((Run::Finished(value), frame)) = result else {
                    panic!("{index} {name}: execution failed")
                };
                assert!(!frame.has_sampled_branch(), "{index} {name}: sampled branch");
                assert!(
                    !solver.trace().to_vec().iter().any(|event| matches!(
                        event,
                        Event::ReadReg(..)
                            | Event::WriteReg(..)
                            | Event::ReadMem { .. }
                            | Event::WriteMem { .. }
                            | Event::Abstract { .. }
                    )),
                    "{index} {name}: impure trace"
                );
                assert_eq!(
                    solver.check_sat(SourceLoc::unknown()),
                    SmtResult::Sat,
                    "{index} {name}: UNSAT"
                );
                if name.starts_with("eq_") || name.starts_with("directed_") {
                    match value {
                        Val::Bool(true) => (),
                        Val::Symbolic(sym) => {
                            solver.assert(Exp::Not(Box::new(Exp::Var(sym))));
                            assert_eq!(
                                solver.check_sat(SourceLoc::unknown()),
                                SmtResult::Unsat,
                                "difference SAT"
                            );
                        }
                        other => panic!("difference or nonbool: {other:?}"),
                    }
                }
            },
        );

        let count = *paths.lock().unwrap();
        assert!(count > 0, "{name}: no completed path");
        if name.starts_with("new_") || name.starts_with("directed_") {
            assert_eq!(count, 1, "{name}: expected one path");
        }
        println!(
            "PASS {name} paths={} all_sat=1 equivalence={}",
            count,
            name.starts_with("eq_") || name.starts_with("directed_")
        );
        std::io::stdout().flush().unwrap();
    }
    eprintln!("PASS {} scalar min/max cases", names.len());
}
