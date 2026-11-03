use isla_lib::bitvector::b129::B129;
use isla_lib::bitvector::BV;
use isla_lib::config::ISAConfig;
use isla_lib::executor::{execute_ir_function, Run};
use isla_lib::init::initialize_architecture;
use isla_lib::ir::{AssertionMode, IRTypeInfo, Symtab, Val};
use isla_lib::ir_lexer::new_ir_lexer;
use isla_lib::ir_parser::IrParser;
use isla_lib::register::RegisterBindings;
use isla_lib::smt::{configure_tastic, Model, SmtResult, Tactic};
use isla_lib::source_loc::SourceLoc;
use isla_lib::zencode;
use std::fs;
use std::sync::Mutex;

fn bits(value: &Val<B129>) -> String {
    match value {
        Val::Bits(value) => format!("0x{value:x}"),
        other => panic!("expected bits: {other:?}"),
    }
}

fn bitvector(hex: &str, width: u32) -> Val<B129> {
    let digits = hex.trim_start_matches("0x");
    let padded = format!("{:0>width$}", digits, width = (width / 4) as usize);
    let value = B129::from_str(&format!("0x{padded}")).expect("parse bitvector");
    assert_eq!(value.len(), width);
    Val::Bits(value)
}

fn register_bits<'a>(
    frame: &'a isla_lib::executor::LocalFrame<'_, B129>,
    symtab: &Symtab,
    name: &str,
) -> &'a Val<B129> {
    let id = symtab.lookup(&zencode::encode(name));
    let value = frame
        .regs()
        .get_last_if_initialized(id)
        .expect("initialized register");
    if matches!(name, "fcsr" | "mstatus") {
        let Val::Struct(fields) = value else {
            panic!("expected struct {name}")
        };
        &fields[&symtab.lookup("zbits")]
    } else {
        value
    }
}

fn assign_bits<'ir>(
    regs: &mut RegisterBindings<'ir, B129>,
    shared: &isla_lib::ir::SharedState<'ir, B129>,
    name: &str,
    value: &str,
    width: u32,
) {
    let id = shared.symtab.lookup(&zencode::encode(name));
    let value = bitvector(value, width);
    let value = if matches!(name, "fcsr" | "mstatus") {
        Val::Struct(
            [(shared.symtab.lookup("zbits"), value)]
                .into_iter()
                .collect(),
        )
    } else {
        value
    };
    regs.assign(id, value, shared);
}

fn run_case(
    function: &str,
    args: &[Val<B129>],
    state: &isla_lib::init::Initialized<'_, B129>,
    regs: &RegisterBindings<'_, B129>,
    expected: &[(String, String, u32)],
) {
    let outcomes = Mutex::new(Vec::new());
    execute_ir_function(
        function,
        args,
        &state.shared_state,
        regs,
        &state.lets,
        &outcomes,
        &|_, _, result, shared, mut solver, outcomes| {
            let (_, frame) = match result {
                Ok((Run::Finished(value), frame)) => (value, frame),
                Ok(_) => panic!("{function}: unfinished"),
                Err((error, _)) => panic!("{function}: {error:?}"),
            };
            assert_eq!(solver.check_sat(SourceLoc::unknown()), SmtResult::Sat);
            let mut model = Model::new(&solver);
            for (name, value, width) in expected {
                let observed = bits(
                    &model
                        .get_val(register_bits(&frame, &shared.symtab, name))
                        .unwrap(),
                );
                assert_eq!(
                    observed,
                    bits(&bitvector(value, *width)),
                    "{function}: {name}"
                );
            }
            outcomes.lock().unwrap().push(());
        },
    );
    assert_eq!(
        outcomes.into_inner().unwrap().len(),
        1,
        "{function}: path count"
    );
}

fn main() {
    configure_tastic(Tactic::Qfaufbv);
    let args: Vec<_> = std::env::args().collect();
    assert!(
        args.len() == 3 || (args.len() == 4 && args[3] == "--legacy-bits-only"),
        "usage: solve-vpr-state-probe IR CONFIG [--legacy-bits-only]"
    );
    let legacy_bits_only = args.len() == 4;
    let ir = Box::leak(fs::read_to_string(&args[1]).unwrap().into_boxed_str());
    let mut symtab = Symtab::new();
    let definitions = IrParser::new()
        .parse(&mut symtab, new_ir_lexer(ir))
        .expect("parse IR");
    let type_info = IRTypeInfo::new(&definitions);
    let config = ISAConfig::<B129>::parse(
        &fs::read_to_string(&args[2]).unwrap(),
        None,
        &symtab,
        &type_info,
    )
    .expect("parse config");
    let definitions = Box::leak(definitions.into_boxed_slice());
    let state = initialize_architecture(
        definitions,
        symtab,
        type_info,
        &config,
        AssertionMode::Optimistic,
        false,
    );
    for name in if legacy_bits_only {
        &["zset_V_bits"][..]
    } else {
        &["zset_V_bits", "zset_V"][..]
    } {
        let id = state
            .shared_state
            .symtab
            .get(name)
            .expect("preserved V setter");
        assert!(state.shared_state.functions.contains_key(&id));
    }

    let names: Vec<_> = (0..32).map(|i| format!("vr{i}")).collect();
    for fast in [false, true] {
        for (fs_name, mstatus) in [
            ("initial", "0x200"),
            ("clean", "0x400"),
            ("dirty", "0x8000000000000600"),
        ] {
            for same in [false, true] {
                for index in [0_u64, 31] {
                    let mut regs = state.regs.clone();
                    regs.assign(
                        state.shared_state.symtab.lookup("z__isla_vector_vpr"),
                        Val::Bool(fast),
                        &state.shared_state,
                    );
                    let target = match index {
                        0 => "0x0123456789abcdef0123456789abcdef".to_string(),
                        _ => "0xfedcba9876543210fedcba9876543210".to_string(),
                    };
                    let mut expected = Vec::new();
                    for (i, name) in names.iter().enumerate() {
                        let original = if i as u64 == index && !same {
                            "0x00000000000000000000000000000000".to_string()
                        } else if i as u64 == index {
                            target.clone()
                        } else {
                            format!("0x{:032x}", 0x5a5a5a5a00000000_u128 | i as u128)
                        };
                        assign_bits(&mut regs, &state.shared_state, name, &original, 128);
                        expected.push((
                            name.clone(),
                            if i as u64 == index {
                                target.clone()
                            } else {
                                original
                            },
                            128,
                        ));
                    }
                    assign_bits(&mut regs, &state.shared_state, "fcsr", "0xa5a5a5a5", 32);
                    assign_bits(&mut regs, &state.shared_state, "mstatus", mstatus, 64);
                    assign_bits(
                        &mut regs,
                        &state.shared_state,
                        "f0",
                        "0x123456789abcdef0",
                        64,
                    );
                    expected.extend([
                        ("fcsr".to_string(), "0xa5a5a5a5".to_string(), 32),
                        ("mstatus".to_string(), "0x8000000000000600".to_string(), 64),
                        ("f0".to_string(), "0x123456789abcdef0".to_string(), 64),
                    ]);
                    let idx = Val::Bits(B129::new(index, 5));
                    let value = bitvector(&target, 128);
                    run_case(
                        "zset_V_bits",
                        &[idx, value.clone()],
                        &state,
                        &regs,
                        &expected,
                    );
                    if !legacy_bits_only {
                        run_case(
                            "zset_V",
                            &[Val::I64(index as i64), value],
                            &state,
                            &regs,
                            &expected,
                        );
                    }
                    println!("VPR fast={fast} VS={fs_name} same={same} index={index}: PASS");
                }
            }
        }
    }
}
