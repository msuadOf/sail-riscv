// Execute the generated small IR with Isla, including its ordinary Sail body.
// A temporary Cargo manifest supplies the isla-lib path dependency.

use isla_lib::bitvector::b64::B64;
use isla_lib::bitvector::BV;
use isla_lib::config::{ISAConfig, Tool};
use isla_lib::executor::{execute_ir_function, Run};
use isla_lib::init::initialize_architecture;
use isla_lib::ir::{AssertionMode, IRTypeInfo, Name, Symtab, Val};
use isla_lib::ir_lexer::new_ir_lexer;
use isla_lib::ir_parser::IrParser;
use isla_lib::smt::smtlib::Exp;
use isla_lib::smt::{configure_tastic, Event, Model, SmtResult, Sym, Tactic};
use isla_lib::source_loc::SourceLoc;
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::Mutex;

fn empty_tool() -> Tool {
    Tool { executable: PathBuf::new(), options: Vec::new() }
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

fn bits(value: &Val<B64>) -> u64 {
    match value {
        Val::Bits(value) => value.unsigned() as u64,
        other => panic!("expected concrete bits, got {other:?}"),
    }
}

fn term(value: &Val<B64>) -> Exp<Sym> {
    match value {
        Val::Symbolic(symbol) => Exp::Var(*symbol),
        Val::Bits(value) => Exp::Bits64(*value),
        Val::Bool(value) => Exp::Bool(*value),
        other => panic!("unexpected symbolic proof term: {other:?}"),
    }
}

fn ordered_tuple<'a>(value: &'a Val<B64>, symtab: &Symtab) -> Vec<&'a Val<B64>> {
    let Val::Struct(fields) = value else { panic!("expected a Sail tuple") };
    let mut fields: Vec<_> = fields.iter().collect();
    fields.sort_by_key(|(name, _)| symtab.to_str(**name));
    fields.into_iter().map(|(_, value)| value).collect()
}

fn bit_equals(value: &Val<B64>, expected: u64, width: u32) -> Exp<Sym> {
    Exp::Eq(Box::new(term(value)), Box::new(Exp::Bits64(B64::new(expected, width))))
}

fn bit_differs(value: &Val<B64>, expected: u64, width: u32) -> Exp<Sym> {
    Exp::Neq(Box::new(term(value)), Box::new(Exp::Bits64(B64::new(expected, width))))
}

fn prove_symbolic_eq(
    state: &isla_lib::init::Initialized<'_, B64>,
    cases: &[(u32, u32, u64, bool)],
) {
    let paths = Mutex::new(0usize);
    execute_ir_function(
        "zstage_b_unknown_eq_inputs",
        &[],
        &state.shared_state,
        &state.regs,
        &state.lets,
        &paths,
        &|_, _, result, shared, mut solver, paths| {
            *paths.lock().unwrap() += 1;
            let Ok((Run::Finished(value), _)) = result else { panic!("unknown Eq execution failed") };
            let fields = ordered_tuple(&value, &shared.symtab);
            assert_eq!(fields.len(), 4);
            for &(a, b, expected_flags, expected_equal) in cases {
                let inputs = Exp::And(
                    Box::new(bit_equals(fields[0], a as u64, 32)),
                    Box::new(bit_equals(fields[1], b as u64, 32)),
                );
                assert_eq!(
                    solver.check_sat_with(&inputs, SourceLoc::unknown()),
                    SmtResult::Sat,
                    "Eq sample {a:#x}, {b:#x} is unreachable",
                );
                let mismatch = Exp::Or(
                    Box::new(bit_differs(fields[2], expected_flags, 5)),
                    Box::new(Exp::Neq(Box::new(term(fields[3])), Box::new(Exp::Bool(expected_equal)))),
                );
                let counterexample = Exp::And(Box::new(inputs), Box::new(mismatch));
                assert_eq!(
                    solver.check_sat_with(&counterexample, SourceLoc::unknown()),
                    SmtResult::Unsat,
                    "Eq result or flags differ for {a:#x}, {b:#x}",
                );
            }
        },
    );
    assert_eq!(*paths.lock().unwrap(), 1, "unknown Eq forked");
}

fn prove_symbolic_add(state: &isla_lib::init::Initialized<'_, B64>, cases: &[(u32, u32, u64)]) {
    let paths = Mutex::new(0usize);
    execute_ir_function(
        "zstage_b_unknown_add_inputs",
        &[],
        &state.shared_state,
        &state.regs,
        &state.lets,
        &paths,
        &|_, _, result, shared, mut solver, paths| {
            *paths.lock().unwrap() += 1;
            let Ok((Run::Finished(value), _)) = result else { panic!("unknown addition execution failed") };
            let fields = ordered_tuple(&value, &shared.symtab);
            assert_eq!(fields.len(), 3);
            for &(a, b, expected) in cases {
                let inputs = Exp::And(
                    Box::new(bit_equals(fields[0], a as u64, 32)),
                    Box::new(bit_equals(fields[1], b as u64, 32)),
                );
                assert_eq!(
                    solver.check_sat_with(&inputs, SourceLoc::unknown()),
                    SmtResult::Sat,
                    "addition sample {a:#x}, {b:#x} is unreachable",
                );
                let counterexample = Exp::And(Box::new(inputs), Box::new(bit_differs(fields[2], expected, 32)));
                assert_eq!(
                    solver.check_sat_with(&counterexample, SourceLoc::unknown()),
                    SmtResult::Unsat,
                    "addition differs for {a:#x}, {b:#x}",
                );
            }
        },
    );
    assert_eq!(*paths.lock().unwrap(), 1, "unknown addition forked");
}

fn run(
    function: &str,
    arguments: &[u32],
    state: &isla_lib::init::Initialized<'_, B64>,
) -> Vec<Val<B64>> {
    let inputs: Vec<_> = arguments.iter().map(|x| Val::Bits(B64::new(*x as u64, 32))).collect();
    let outputs = Mutex::new(Vec::new());
    execute_ir_function(
        function,
        &inputs,
        &state.shared_state,
        &state.regs,
        &state.lets,
        &outputs,
        &|_, _, result, shared, mut solver, outputs| {
            let value = match result {
                Ok((Run::Finished(value), _)) => {
                    if function == "zstage_b_cpp_probe" {
                        let target = shared.symtab.lookup("zriscv_f32Eq");
                        assert!(solver.trace().to_vec().iter().any(|event| {
                            matches!(event, Event::Function { name, call: true } if *name == target)
                        }), "ordinary Sail Eq body was not entered");
                    }
                    assert_eq!(solver.check_sat(SourceLoc::unknown()), SmtResult::Sat);
                    Model::new(&solver).get_val(&value).expect("materialize result")
                }
                Ok((_, _)) => panic!("function did not finish"),
                Err((error, _)) => panic!("Isla execution failed: {error:?}"),
            };
            outputs.lock().unwrap().push(value);
        },
    );
    outputs.into_inner().unwrap()
}

fn main() {
    configure_tastic(Tactic::Qfaufbv);
    let ir_file = std::env::args().nth(1).expect("usage: run_stage_b IR_FILE");
    let ir = Box::leak(std::fs::read_to_string(ir_file).expect("read IR").into_boxed_str());
    let mut symtab = Symtab::new();
    let definitions = IrParser::new().parse(&mut symtab, new_ir_lexer(ir)).expect("parse IR");
    let type_info = IRTypeInfo::new(&definitions);
    let definitions = Box::leak(definitions.into_boxed_slice());
    let mut config = empty_config();
    config.trace_functions.insert(symtab.lookup("zriscv_f32Eq"));
    let state = initialize_architecture(definitions, symtab, type_info, &config, AssertionMode::Optimistic, false);

    let comparisons = [
        (0x3f800000, 0x3f800000, 0, true),
        (0x00000000, 0x80000000, 0, true),
        (0x3f800000, 0x40000000, 0, false),
        (0x7fc00001, 0x3f800000, 0, false),
        (0x7fc00001, 0x7fc00001, 0, false),
        (0x7f800001, 0x3f800000, 0x10, false),
        (0x3f800000, 0x7f800001, 0x10, false),
        (0x7fc00001, 0x7f800001, 0x10, false),
    ];
    for (a, b, expected_flags, expected_equal) in comparisons {
        let results = run("zriscv_f32Eq", &[a, b], &state);
        assert_eq!(results.len(), 1, "Eq took more than one execution path");
        let Val::Struct(fields) = &results[0] else { panic!("Eq must return flags and bool") };
        let mut flags = None;
        let mut equal = None;
        for value in fields.values() {
            match value {
                Val::Bits(_) => flags = Some(bits(value)),
                Val::Bool(value) => equal = Some(*value),
                other => panic!("unexpected Eq result field: {other:?}"),
            }
        }
        assert_eq!(flags, Some(expected_flags), "Eq flags for {a:#x}, {b:#x}");
        assert_eq!(equal, Some(expected_equal), "Eq result for {a:#x}, {b:#x}");
    }

    prove_symbolic_eq(&state, &comparisons);

    let unknown = run("zstage_b_unknown_eq", &[], &state);
    assert_eq!(unknown.len(), 1, "unknown Eq inputs caused a data path fork");
    assert_eq!(run("zstage_b_cpp_probe", &[0x3f800000, 0x3f800000], &state).len(), 1);

    for (a, b, expected) in [
        (0x3f800000, 0x40000000, 0x40400000),
        (0x7fc00001, 0x3f800000, 0x7fc00000),
    ] {
        let results = run("zdemo_f32_add_bits", &[a, b], &state);
        assert_eq!(results.len(), 1, "addition demo forked");
        assert_eq!(bits(&results[0]), expected, "addition demo for {a:#x}, {b:#x}");
    }

    prove_symbolic_add(
        &state,
        &[(0x3f800000, 0x40000000, 0x40400000), (0x7fc00001, 0x3f800000, 0x7fc00000)],
    );

    let bf16 = run("zstage_b_bf16_interface_bits", &[0x3f800000], &state);
    assert_eq!(bf16.len(), 1, "BF16 interface forked");
    assert_eq!(bits(&bf16[0]), 0x3f80);
    println!("stage B Isla runtime PASS: concrete and symbolic Eq, addition demo, BF16 interface");
}
