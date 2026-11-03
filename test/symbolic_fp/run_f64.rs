// Execute all f64 SYMBOLIC wrappers from a small isolated IR. Each case line is
// FUNCTION ARG_WIDTH:HEX ... EXPECTED_FLAGS EXPECTED_RESULT_WIDTH:HEX.
use isla_lib::bitvector::b64::B64;
use isla_lib::bitvector::BV;
use isla_lib::config::{ISAConfig, Tool};
use isla_lib::executor::{execute_ir_function, Run};
use isla_lib::init::initialize_architecture;
use isla_lib::ir::{AssertionMode, IRTypeInfo, Name, Symtab, Val};
use isla_lib::ir_lexer::new_ir_lexer;
use isla_lib::ir_parser::IrParser;
use isla_lib::smt::smtlib::Exp;
use isla_lib::smt::{configure_tastic, configure_z3_timeout, Event, Model, SmtResult, Sym, Tactic};
use isla_lib::source_loc::SourceLoc;
use std::collections::{BTreeMap, HashMap, HashSet};
use std::path::PathBuf;
use std::sync::Mutex;

fn empty_config() -> ISAConfig<B64> {
    let tool = || Tool { executable: PathBuf::new(), options: Vec::new() };
    ISAConfig {
        pc: Name::from_u32(u32::MAX),
        register_event_sets: HashMap::new(),
        assembler: tool(), objdump: tool(), nm: tool(), linker: tool(),
        page_table_base: 0, page_size: 0, s2_page_table_base: 0, s2_page_size: 0,
        default_page_table_setup: String::new(),
        thread_base: 0, thread_top: 0, thread_stride: 0,
        symbolic_addr_base: 0, symbolic_addr_top: 0, symbolic_addr_stride: 0,
        default_registers: HashMap::new(), reset_registers: Vec::new(), reset_constraints: Vec::new(),
        const_primops: HashMap::new(), function_assumptions: Vec::new(),
        register_renames: HashMap::new(), ignored_registers: HashSet::new(),
        relaxed_registers: HashSet::new(), probes: HashSet::new(),
        probe_functions: HashSet::new(), trace_functions: HashSet::new(),
        translation_function: None, in_program_order: HashSet::new(),
        default_sizeof: 0, zero_announce_exit: false,
        memory_regions: None, page_table_config: None, pmp: None,
        clint_enabled: None, execution_limits: None,
    }
}

fn parse_arg(input: &str) -> Val<B64> {
    if input == "true" { return Val::Bool(true) }
    if input == "false" { return Val::Bool(false) }
    let (width, value) = input.split_once(':').expect("argument must be WIDTH:HEX");
    let width: u32 = width.parse().expect("width");
    let value = u64::from_str_radix(value.trim_start_matches("0x"), 16).expect("hex");
    Val::Bits(B64::new(value, width))
}

fn unpack(value: &Val<B64>, symtab: &Symtab) -> (u64, Val<B64>) {
    let Val::Struct(fields) = value else { panic!("expected flags/result tuple: {value:?}") };
    let mut ordered: Vec<_> = fields.iter().collect();
    ordered.sort_by_key(|(name, _)| symtab.to_str(**name));
    assert_eq!(ordered.len(), 2);
    let Val::Bits(flags) = ordered[0].1 else { panic!("flags are not bits") };
    (flags.unsigned() as u64, ordered[1].1.clone())
}

fn ordered_tuple(value: &Val<B64>, symtab: &Symtab) -> Vec<Val<B64>> {
    let Val::Struct(fields) = value else { panic!("expected tuple: {value:?}") };
    let mut ordered: Vec<_> = fields.iter().collect();
    ordered.sort_by_key(|(name, _)| symtab.to_str(**name));
    ordered.into_iter().map(|(_, value)| value.clone()).collect()
}

fn term(value: &Val<B64>) -> Exp<Sym> {
    match value {
        Val::Symbolic(symbol) => Exp::Var(*symbol),
        Val::Bits(bits) => Exp::Bits64(*bits),
        Val::Bool(value) => Exp::Bool(*value),
        _ => panic!("unexpected symbolic term: {value:?}"),
    }
}

fn equals(a: &Val<B64>, b: &Val<B64>) -> Exp<Sym> {
    Exp::Eq(Box::new(term(a)), Box::new(term(b)))
}

fn differs(a: &Val<B64>, b: &Val<B64>) -> Exp<Sym> {
    Exp::Neq(Box::new(term(a)), Box::new(term(b)))
}

#[derive(Clone)]
struct Case {
    input: Vec<Val<B64>>,
    flags: Val<B64>,
    result: Val<B64>,
    description: String,
}

fn main() {
    configure_tastic(Tactic::Qfaufbv);
    configure_z3_timeout(Some(std::time::Duration::from_secs(10)));
    let mut cli = std::env::args().skip(1);
    let ir_file = cli.next().expect("IR file");
    let cases_file = cli.next().expect("case file");
    let ir = Box::leak(std::fs::read_to_string(ir_file).expect("read IR").into_boxed_str());
    let mut symtab = Symtab::new();
    let definitions = IrParser::new().parse(&mut symtab, new_ir_lexer(ir)).expect("parse IR");
    let type_info = IRTypeInfo::new(&definitions);
    let definitions = Box::leak(definitions.into_boxed_slice());
    let cases = std::fs::read_to_string(cases_file).expect("read cases");
    let mut config = empty_config();
    for line in cases.lines().filter(|line| !line.trim().is_empty() && !line.starts_with('#')) {
        let name = line.split_whitespace().next().unwrap();
        config.trace_functions.insert(symtab.lookup(&format!("z{name}")));
    }
    let state = initialize_architecture(definitions, symtab, type_info, &config, AssertionMode::Optimistic, false);
    let mut checked = 0;
    let mut groups: BTreeMap<String, Vec<Case>> = BTreeMap::new();
    for line in cases.lines().filter(|line| !line.trim().is_empty() && !line.starts_with('#')) {
        let columns: Vec<_> = line.split_whitespace().collect();
        assert!(columns.len() >= 4, "bad case: {line}");
        let function = format!("z{}", columns[0]);
        let input: Vec<_> = columns[1..columns.len() - 2].iter().map(|x| parse_arg(x)).collect();
        let expected_flags = u64::from_str_radix(columns[columns.len() - 2].trim_start_matches("0x"), 16).unwrap();
        let expected_value = parse_arg(columns[columns.len() - 1]);
        groups.entry(columns[0].to_string()).or_default().push(Case {
            input: input.clone(),
            flags: Val::Bits(B64::new(expected_flags, 5)),
            result: expected_value.clone(),
            description: line.to_string(),
        });
        let outputs = Mutex::new(Vec::new());
        execute_ir_function(
            &function, &input, &state.shared_state, &state.regs, &state.lets, &outputs,
            &|_, _, result, _, mut solver, outputs| {
                let Ok((Run::Finished(value), _)) = result else { panic!("{function} did not finish") };
                assert_eq!(solver.check_sat(SourceLoc::unknown()), SmtResult::Sat);
                let value = Model::new(&solver).get_val(&value).expect("materialize result");
                outputs.lock().unwrap().push(value);
            },
        );
        let outputs = outputs.into_inner().unwrap();
        assert_eq!(outputs.len(), 1, "{function} forked for {line}");
        let (actual_flags, actual_value) = unpack(&outputs[0], &state.shared_state.symtab);
        assert_eq!(actual_flags, expected_flags, "flags: {line}");
        match (&actual_value, &expected_value) {
            (Val::Bits(actual), Val::Bits(expected)) =>
                assert_eq!(actual, expected, "result: {line}"),
            (Val::Bool(actual), Val::Bool(expected)) =>
                assert_eq!(actual, expected, "result: {line}"),
            _ => panic!("result type mismatch: {line}"),
        }
        checked += 1;
    }
    println!("f64 concrete cases PASS: {checked}");

    let mut proved = 0;
    for (name, cases) in groups {
        let unknown = format!("zf64_unknown_{name}_inputs");
        let paths = Mutex::new(0usize);
        execute_ir_function(
            &unknown, &[], &state.shared_state, &state.regs, &state.lets, &paths,
            &|_, _, result, shared, mut solver, paths| {
                *paths.lock().unwrap() += 1;
                let Ok((Run::Finished(value), _)) = result else { panic!("{unknown} did not finish") };
                let target = shared.symtab.lookup(&format!("z{name}"));
                assert!(solver.trace().to_vec().iter().any(|event| {
                    matches!(event, Event::Function { name, call: true } if *name == target)
                }), "ordinary model function was not entered: {name}");
                let fields = ordered_tuple(&value, &shared.symtab);
                for case in &cases {
                    assert_eq!(fields.len(), case.input.len() + 2);
                    let mut inputs = Exp::Bool(true);
                    for (actual, expected) in fields.iter().zip(&case.input) {
                        inputs = Exp::And(Box::new(inputs), Box::new(equals(actual, expected)));
                    }
                    assert_eq!(solver.check_sat_with(&inputs, SourceLoc::unknown()), SmtResult::Sat,
                        "unreachable input: {}", case.description);
                    let mismatch = Exp::Or(
                        Box::new(differs(&fields[case.input.len()], &case.flags)),
                        Box::new(differs(&fields[case.input.len() + 1], &case.result)),
                    );
                    let counterexample = Exp::And(Box::new(inputs), Box::new(mismatch));
                    assert_eq!(solver.check_sat_with(&counterexample, SourceLoc::unknown()), SmtResult::Unsat,
                        "non-unique result or flags: {}", case.description);
                }
            },
        );
        assert_eq!(*paths.lock().unwrap(), 1, "{unknown} forked");
        proved += cases.len();
        eprintln!("proved {name}: {}", cases.len());
    }
    println!("f64 symbolic cases PASS: {proved}");
}
