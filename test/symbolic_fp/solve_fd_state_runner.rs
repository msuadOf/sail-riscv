use isla_lib::bitvector::b129::B129;
use isla_lib::bitvector::BV;
use isla_lib::config::ISAConfig;
use isla_lib::executor::{execute_ir_function, Run};
use isla_lib::init::initialize_architecture;
use isla_lib::ir::{AssertionMode, IRTypeInfo, Symtab, UVal, Val};
use isla_lib::ir_lexer::new_ir_lexer;
use isla_lib::ir_parser::IrParser;
use isla_lib::primop_util::smt_value;
use isla_lib::register::RegisterBindings;
use isla_lib::smt::smtlib::{bits64, Exp};
use isla_lib::smt::{configure_tastic, Model, SmtResult, Tactic};
use isla_lib::source_loc::SourceLoc;
use isla_lib::zencode;
use std::fs;
use std::sync::Mutex;

// The wrapper records pre-state and constructs unknown flags. Its only FD
// operation is a call to the generated Sail function zaccrue_fflags.
const SYMBOLIC_WRAPPER: &str = r#"
register zfd_probe_old_fcsr : %bv32
register zfd_probe_old_mstatus : %bv64
register zfd_probe_flags : %bv5
val zfd_probe_accrue : (%unit) -> %unit
fn zfd_probe_accrue(zarg) {
  zfd_probe_old_fcsr = zfcsr.zbits;
  zfd_probe_old_mstatus = zmstatus.zbits;
  zzfd_size : %i;
  zzfd_size = zz5i64zDzKz5i(5);
  zzfd_unknown : %bv;
  zzfd_unknown = zundefined_bitvector(zzfd_size);
  zzfd_flags : %bv5;
  zzfd_flags = zzfd_unknown;
  zfd_probe_flags = zzfd_flags;
  return = zaccrue_fflags(zzfd_flags);
  end;
}
"#;

fn bits(value: &Val<B129>) -> String {
    match value {
        Val::Bits(value) => format!("0x{value:x}"),
        other => panic!("expected bits: {other:?}"),
    }
}

fn parse_bits(value: u64, width: u32) -> Val<B129> {
    let bits = B129::new(value, width);
    assert_eq!(bits.len(), width);
    Val::Bits(bits)
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

fn concrete_register(
    frame: &isla_lib::executor::LocalFrame<'_, B129>,
    symtab: &Symtab,
    model: &mut Model<B129>,
    name: &str,
) -> String {
    bits(&model.get_val(register_bits(frame, symtab, name)).unwrap())
}

fn assign_bits<'ir>(
    regs: &mut RegisterBindings<'ir, B129>,
    shared: &isla_lib::ir::SharedState<'ir, B129>,
    name: &str,
    value: u64,
    width: u32,
) {
    let id = shared.symtab.lookup(&zencode::encode(name));
    let value = parse_bits(value, width);
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

fn set_fast<'ir>(
    regs: &mut RegisterBindings<'ir, B129>,
    shared: &isla_lib::ir::SharedState<'ir, B129>,
    fast: bool,
) {
    let id = shared.symtab.lookup("z__isla_vector_fpr");
    regs.assign(id, Val::Bool(fast), shared);
}

fn run_concrete(
    function: &str,
    args: &[Val<B129>],
    state: &isla_lib::init::Initialized<'_, B129>,
    regs: &RegisterBindings<'_, B129>,
    expected_return: Option<u64>,
    expected_registers: &[(&str, u64, u32)],
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
            let (value, frame) = match result {
                Ok((Run::Finished(value), frame)) => (value, frame),
                Ok(_) => panic!("{function}: unfinished"),
                Err((error, _)) => panic!("{function}: {error:?}"),
            };
            assert_eq!(solver.check_sat(SourceLoc::unknown()), SmtResult::Sat);
            let mut model = Model::new(&solver);
            if let Some(expected) = expected_return {
                assert_eq!(
                    bits(&model.get_val(&value).unwrap()),
                    bits(&parse_bits(expected, 64))
                );
            }
            for (name, expected, width) in expected_registers {
                let actual = concrete_register(&frame, &shared.symtab, &mut model, name);
                assert_eq!(
                    actual,
                    bits(&parse_bits(*expected, *width)),
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

fn run_symbolic(state: &isla_lib::init::Initialized<'_, B129>) {
    let mut regs = state.regs.clone();
    for name in ["fcsr", "mstatus"] {
        let id = state.shared_state.symtab.lookup(&zencode::encode(name));
        let ty = &state.shared_state.registers[&id];
        regs.insert(id, false, UVal::Uninit(ty));
    }
    let outcomes = Mutex::new(Vec::new());
    execute_ir_function(
        "zfd_probe_accrue",
        &[Val::Unit],
        &state.shared_state,
        &regs,
        &state.lets,
        &outcomes,
        &|_, _, result, shared, mut solver, outcomes| {
            let (_, frame) = match result {
                Ok((Run::Finished(value), frame)) => (value, frame),
                Ok(_) => panic!("symbolic accrue unfinished"),
                Err((error, _)) => panic!("symbolic accrue failed: {error:?}"),
            };
            assert_eq!(solver.check_sat(SourceLoc::unknown()), SmtResult::Sat);
            let expr = |name: &str| {
                smt_value(
                    register_bits(&frame, &shared.symtab, name),
                    SourceLoc::unknown(),
                )
                .unwrap()
            };
            let old_csr = expr("fd_probe_old_fcsr");
            let old_ms = expr("fd_probe_old_mstatus");
            let flags = expr("fd_probe_flags");
            let old_flags = Exp::Extract(4, 0, Box::new(old_csr.clone()));
            let new_flags = Exp::Bvor(Box::new(old_flags.clone()), Box::new(flags));
            let changed = Exp::Neq(Box::new(old_flags), Box::new(new_flags.clone()));
            assert_eq!(
                solver.check_sat_with(&changed, SourceLoc::unknown()),
                SmtResult::Sat
            );
            assert_eq!(
                solver.check_sat_with(&Exp::Not(Box::new(changed.clone())), SourceLoc::unknown()),
                SmtResult::Sat
            );
            let expected_csr = Exp::Concat(
                Box::new(Exp::Extract(31, 5, Box::new(old_csr))),
                Box::new(new_flags),
            );
            let dirty = Exp::Bvor(
                Box::new(old_ms.clone()),
                Box::new(bits64(0x8000000000006000, 64)),
            );
            let expected_ms = Exp::Ite(Box::new(changed), Box::new(dirty), Box::new(old_ms));
            let mismatch = Exp::Or(
                Box::new(Exp::Neq(Box::new(expr("fcsr")), Box::new(expected_csr))),
                Box::new(Exp::Neq(Box::new(expr("mstatus")), Box::new(expected_ms))),
            );
            assert_eq!(
                solver.check_sat_with(&mismatch, SourceLoc::unknown()),
                SmtResult::Unsat
            );
            outcomes.lock().unwrap().push(());
        },
    );
    assert_eq!(
        outcomes.into_inner().unwrap().len(),
        1,
        "symbolic accrue path count"
    );
    println!("symbolic accrue: one SAT path, state difference UNSAT");
}

fn main() {
    configure_tastic(Tactic::Qfaufbv);
    let args: Vec<_> = std::env::args().collect();
    assert!(
        args.len() == 3 || (args.len() == 4 && args[3] == "--legacy-bits-only"),
        "usage: solve-fd-state-probe IR CONFIG [--legacy-bits-only]"
    );
    let legacy_bits_only = args.len() == 4;
    let mut ir = fs::read_to_string(&args[1]).unwrap();
    ir.push_str(SYMBOLIC_WRAPPER);
    let ir = Box::leak(ir.into_boxed_str());
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
    if !legacy_bits_only {
        for name in ["zget_F", "zset_F"] {
            let id = state
                .shared_state
                .symtab
                .get(name)
                .expect("preserved Fregno entry");
            assert!(
                state.shared_state.functions.contains_key(&id),
                "missing {name} body"
            );
        }
    }

    for fast in [false, true] {
        for (index, value) in [(0_u64, 0x0123456789abcdef_u64), (31, 0xfedcba9876543210)] {
            let mut regs = state.regs.clone();
            set_fast(&mut regs, &state.shared_state, fast);
            let names: Vec<_> = (0..32).map(|i| format!("f{i}")).collect();
            let register_value = |i: usize| match i {
                0 => 0x0123456789abcdef,
                31 => 0xfedcba9876543210,
                _ => 0x5a5a5a5a00000000 | i as u64,
            };
            for (i, name) in names.iter().enumerate() {
                assign_bits(&mut regs, &state.shared_state, name, register_value(i), 64);
            }
            assign_bits(&mut regs, &state.shared_state, "fcsr", 0x7f, 32);
            assign_bits(&mut regs, &state.shared_state, "mstatus", 0x2600, 64);
            let mut expected: Vec<_> = names
                .iter()
                .enumerate()
                .map(|(i, name)| (name.as_str(), register_value(i), 64))
                .collect();
            expected.extend([("fcsr", 0x7f, 32), ("mstatus", 0x2600, 64)]);
            run_concrete(
                "zget_F_bits",
                &[parse_bits(index, 5)],
                &state,
                &regs,
                Some(value),
                &expected,
            );
            if !legacy_bits_only {
                run_concrete(
                    "zget_F",
                    &[Val::I64(index as i64)],
                    &state,
                    &regs,
                    Some(value),
                    &expected,
                );
            }
        }
    }
    println!("getter: f0/f31 fast and normal values and read-only state PASS");

    for fast in [false, true] {
        for fs in [0x2600_u64, 0x4600, 0x8000000000006600] {
            for same in [false, true] {
                let mut regs = state.regs.clone();
                set_fast(&mut regs, &state.shared_state, fast);
                let value = 0xfedcba9876543210;
                let names: Vec<_> = (0..32).map(|i| format!("f{i}")).collect();
                for (i, name) in names.iter().enumerate() {
                    assign_bits(
                        &mut regs,
                        &state.shared_state,
                        name,
                        if i == 31 {
                            if same {
                                value
                            } else {
                                0
                            }
                        } else {
                            0x5a5a5a5a00000000 | i as u64
                        },
                        64,
                    );
                }
                assign_bits(&mut regs, &state.shared_state, "fcsr", 0x7f, 32);
                assign_bits(&mut regs, &state.shared_state, "mstatus", fs, 64);
                let mut expected: Vec<_> = names
                    .iter()
                    .enumerate()
                    .map(|(i, name)| {
                        (
                            name.as_str(),
                            if i == 31 {
                                value
                            } else {
                                0x5a5a5a5a00000000 | i as u64
                            },
                            64,
                        )
                    })
                    .collect();
                expected.extend([("fcsr", 0x7f, 32), ("mstatus", 0x8000000000006600, 64)]);
                run_concrete(
                    "zset_F_bits",
                    &[parse_bits(31, 5), parse_bits(value, 64)],
                    &state,
                    &regs,
                    None,
                    &expected,
                );
                if !legacy_bits_only {
                    run_concrete(
                        "zset_F",
                        &[Val::I64(31), parse_bits(value, 64)],
                        &state,
                        &regs,
                        None,
                        &expected,
                    );
                }
            }
        }
    }
    println!("setter: fast/normal × FS initial/clean/dirty × same/different PASS");

    for (old_flags, flags, fs) in [
        (0_u64, 0_u64, 0x2600_u64),
        (31, 0, 0x4600),
        (0, 1, 0x2600),
        (30, 1, 0x4600),
        (1, 1, 0x2600),
    ] {
        let mut regs = state.regs.clone();
        assign_bits(
            &mut regs,
            &state.shared_state,
            "fcsr",
            0xa5a5a5a0 | old_flags,
            32,
        );
        assign_bits(&mut regs, &state.shared_state, "mstatus", fs, 64);
        let changed = old_flags | flags != old_flags;
        let expected = [
            ("fcsr", 0xa5a5a5a0 | old_flags | flags, 32),
            ("mstatus", if changed { 0x8000000000006600 } else { fs }, 64),
        ];
        run_concrete(
            "zaccrue_fflags",
            &[parse_bits(flags, 5)],
            &state,
            &regs,
            None,
            &expected,
        );
    }
    println!("concrete accrue: changed/unchanged, existing flag and FS states PASS");
    run_symbolic(&state);
}
