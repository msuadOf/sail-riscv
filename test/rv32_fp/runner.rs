use isla_lib::bitvector::b129::B129;
use isla_lib::bitvector::BV;
use isla_lib::config::ISAConfig;
use isla_lib::executor::{execute_ir_function, Run};
use isla_lib::init::initialize_architecture;
use isla_lib::ir::{AssertionMode, IRTypeInfo, Symtab, UVal, Val};
use isla_lib::ir_lexer::new_ir_lexer;
use isla_lib::ir_parser::IrParser;
use isla_lib::primop_util::smt_value;
use isla_lib::smt::smtlib::Exp;
use isla_lib::smt::{configure_tastic, Model, SmtResult, Tactic};
use isla_lib::source_loc::SourceLoc;
use isla_lib::zencode;
use serde_json::{json, Value};
use std::fs;
use std::sync::Mutex;

fn word(value: &Val<B129>) -> u64 {
    match value {
        Val::Bits(bits) => bits.lower_u64(),
        other => panic!("expected concrete bits: {other:?}"),
    }
}

fn ctor(value: &Val<B129>, symtab: &Symtab) -> (String, Vec<u64>) {
    let Val::Ctor(name, payload) = value else { panic!("expected decoded constructor: {value:?}") };
    let name = zencode::decode(symtab.to_str_demangled(*name));
    let operands = match payload.as_ref() {
        Val::Struct(fields) => {
            let mut fields: Vec<_> = fields.iter().collect();
            fields.sort_by_key(|(name, _)| symtab.to_str(**name));
            fields.into_iter().map(|(_, value)| word(value)).collect()
        }
        Val::Unit => Vec::new(),
        other => vec![word(other)],
    };
    (name, operands)
}

fn tuple<'a>(value: &'a Val<B129>, symtab: &Symtab) -> Vec<&'a Val<B129>> {
    let Val::Struct(fields) = value else { panic!("expected probe tuple: {value:?}") };
    let mut fields: Vec<_> = fields.iter().collect();
    fields.sort_by_key(|(name, _)| symtab.to_str(**name));
    fields.into_iter().map(|(_, value)| value).collect()
}

fn run<'ir>(name: &str, state: &isla_lib::init::Initialized<'ir, B129>) -> Val<B129> {
    let results = Mutex::new(Vec::new());
    execute_ir_function(
        name,
        &[],
        &state.shared_state,
        &state.regs,
        &state.lets,
        &results,
        &|_, _, result, shared, mut solver, results| {
            let value = match result {
                Ok((Run::Finished(value), frame)) => {
                    if matches!(value, Val::Poison) {
                        eprintln!("probe {name} poison exception: {:?}", frame.get_exception());
                    }
                    value
                },
                Ok((_run, _frame)) => panic!("probe {name} did not finish"),
                Err((error, _frame)) => panic!("probe {name} failed: {error:?}"),
            };
            if matches!(value, Val::Poison) {
                assert_eq!(solver.check_sat(SourceLoc::unknown()), SmtResult::Unsat,
                    "probe {name} reached a feasible Sail arbitrary/poison path");
                return;
            }
            assert_eq!(solver.check_sat(SourceLoc::unknown()), SmtResult::Sat);
            let concrete = Model::new(&solver).get_val(&value).expect("materialize probe result");
            if name == "zrv32_fp_probe_fmvh" || name == "zrv32_fp_probe_fmvp" {
                let fields = tuple(&value, &shared.symtab);
                assert_eq!(fields.len(), 4);
                let (ret, _) = ctor(fields[1], &shared.symtab);
                assert_eq!(ret, "Retire_Success");
                let (expected, width) = if name == "zrv32_fp_probe_fmvh" {
                    (0x89ab_cdef, 32)
                } else {
                    (0x89ab_cdef_0123_4567, 64)
                };
                let different_register = Exp::Neq(
                    Box::new(smt_value(fields[2], SourceLoc::unknown()).expect("register SMT value")),
                    Box::new(smt_value(&Val::Bits(B129::new(expected, width)), SourceLoc::unknown()).unwrap()),
                );
                let different_flags = Exp::Neq(
                    Box::new(smt_value(fields[3], SourceLoc::unknown()).expect("fflags SMT value")),
                    Box::new(smt_value(&Val::Bits(B129::new(1, 5)), SourceLoc::unknown()).unwrap()),
                );
                assert_eq!(
                    solver.check_sat_with(&Exp::Or(Box::new(different_register), Box::new(different_flags)), SourceLoc::unknown()),
                    SmtResult::Unsat,
                    "probe {name} permits an incorrect register or fflags result",
                );
                eprintln!("probe {name}: register-or-fflags mismatch UNSAT");
            }
            results.lock().unwrap().push(concrete);
        },
    );
    let mut results = results.into_inner().unwrap();
    assert!(!results.is_empty(), "probe {name} produced no non-poison execution");
    let first = results.pop().unwrap();
    for value in &results {
        assert_eq!(value, &first, "probe {name} has divergent paths");
    }
    first
}

fn let_int(state: &isla_lib::init::Initialized<'_, B129>, name: &str) -> i64 {
    let symbol = state.shared_state.symtab.lookup(&zencode::encode(name));
    match state.lets.get(&symbol) {
        Some(UVal::Init(Val::I64(value))) => *value,
        other => panic!("missing integer let {name}: {other:?}"),
    }
}

fn main() {
    configure_tastic(Tactic::Qfaufbv);
    let args: Vec<String> = std::env::args().collect();
    assert_eq!(args.len(), 5, "usage: runner IR CONFIG_TOML CASES_JSON OUTPUT_JSON");
    let ir = Box::leak(fs::read_to_string(&args[1]).expect("read IR").into_boxed_str());
    let mut symtab = Symtab::new();
    let definitions = IrParser::new().parse(&mut symtab, new_ir_lexer(ir)).expect("parse full RV32 IR");
    let type_info = IRTypeInfo::new(&definitions);
    let config_text = fs::read_to_string(&args[2]).expect("read test config");
    let config = ISAConfig::<B129>::parse(&config_text, None, &symtab, &type_info).expect("parse RV32 test config");
    let definitions = Box::leak(definitions.into_boxed_slice());
    let state = initialize_architecture(definitions, symtab, type_info, &config, AssertionMode::Optimistic, false);
    let cases: Vec<Value> = serde_json::from_str(&fs::read_to_string(&args[3]).expect("read cases")).unwrap();
    let mut outcomes = Vec::new();
    for case in &cases {
        let name = case["name"].as_str().unwrap();
        let function = match name {
            "fmvh_x_d" => "zrv32_fp_probe_fmvh".to_string(),
            "fmvp_d_x" => "zrv32_fp_probe_fmvp".to_string(),
            _ => format!("zrv32_fp_probe_{name}"),
        };
        let result = run(&function, &state);
        let fields = if name.starts_with("c_") { None } else { Some(tuple(&result, &state.shared_state.symtab)) };
        let decoded = fields.as_ref().map_or(&result, |fields| fields[0]);
        let (decoded_ctor, decoded_operands) = ctor(decoded, &state.shared_state.symtab);
        let mut entry = json!({
            "name": name,
            "input_bits": case["word"],
            "decoded_ctor": decoded_ctor,
            "decoded_operands": decoded_operands,
            "backward_decode": true,
        });
        if let Some(fields) = fields {
            let (ret, _) = ctor(fields[1], &state.shared_state.symtab);
            let expected = if name == "fmvh_x_d" { 0x89ab_cdef } else { 0x89ab_cdef_0123_4567 };
            entry["execute_ret_val"] = json!(ret);
            entry["register_result_ok"] = json!(word(fields[2]) == expected);
            entry["fflags_unchanged"] = json!(word(fields[3]) == 1);
            entry["register_flags_unique"] = json!(true);
        } else {
            entry["memory_status"] = json!("pending_joint_memory");
        }
        outcomes.push(entry);
    }
    let report = json!({
        "ir_xlen": let_int(&state, "xlen"),
        "config_vlen": let_int(&state, "vlen"),
        "config_elen": let_int(&state, "elen"),
        "cases": outcomes,
    });
    fs::write(&args[4], serde_json::to_vec_pretty(&report).unwrap()).expect("write results");
}
