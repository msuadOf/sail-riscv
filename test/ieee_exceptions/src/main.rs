use isla_lib::bitvector::{b64::B64, BV};
use isla_lib::config::{ISAConfig, Tool};
use isla_lib::executor::{execute_ir_function, execute_ir_function_with_checkpoint, Run};
use isla_lib::init::initialize_architecture;
use isla_lib::ir::{AssertionMode, Def, IRTypeInfo, Name, Symtab, Val};
use isla_lib::ir_lexer::new_ir_lexer;
use isla_lib::ir_parser::IrParser;
use isla_lib::primop_util::smt_value;
use isla_lib::smt::smtlib::{Exp, Ty as SmtTy};
use isla_lib::smt::{configure_tastic, Config, Context, Model, SmtResult, Solver, Tactic};
use isla_lib::source_loc::SourceLoc;
use std::collections::{HashMap, HashSet};
use std::io::{self, BufRead};
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

fn bits_pair(value: Val<B64>) -> Result<(u64, u64), String> {
    let Val::Struct(fields) = value else {
        return Err("probe did not return a tuple".into());
    };
    let mut flags = None;
    let mut result = None;
    for field in fields.into_values() {
        let Val::Bits(bits) = field else {
            return Err("tuple field is not bits".into());
        };
        if bits.len() == 5 {
            flags = Some(bits.lower_u64());
        } else {
            result = Some(bits.lower_u64());
        }
    }
    Ok((
        flags.ok_or("missing flags")?,
        result.ok_or("missing result")?,
    ))
}

fn parse_hex(s: &str) -> Result<u64, String> {
    u64::from_str_radix(s.strip_prefix("0x").unwrap_or(s), 16).map_err(|e| e.to_string())
}

fn prove_unique(
    value: &Val<B64>,
    flags: u64,
    bits: u64,
    width: u32,
    comparison: bool,
    skip_result: bool,
    state: &isla_lib::ir::SharedState<B64>,
    solver: &mut isla_lib::smt::Solver<B64>,
) -> Result<(), String> {
    let Val::Struct(fields) = value else {
        return Err("probe did not return tuple".into());
    };
    let mut flag_exp = None;
    let mut result_exp = None;
    for (field, value) in fields {
        let exp =
            smt_value(value, SourceLoc::unknown()).map_err(|e| format!("SMT value: {:?}", e))?;
        if state.symtab.to_str(*field).ends_with('0') {
            flag_exp = Some(exp);
        } else {
            result_exp = Some(exp);
        }
    }
    let different_flags = Exp::Neq(
        Box::new(flag_exp.ok_or("missing flags")?),
        Box::new(Exp::Bits64(B64::new(flags, 5))),
    );
    let mismatch = if skip_result {
        different_flags
    } else {
        let result_width = if comparison { 1 } else { width };
        let different_result = Exp::Neq(
            Box::new(result_exp.ok_or("missing result")?),
            Box::new(Exp::Bits64(B64::new(bits, result_width))),
        );
        Exp::Or(Box::new(different_flags), Box::new(different_result))
    };
    solver.assert(mismatch);
    match solver.check_sat(SourceLoc::unknown()) {
        SmtResult::Unsat => Ok(()),
        other => Err(format!("non-unique flags/result: {:?}", other)),
    }
}

fn f32_nan(bits: u64) -> bool {
    (bits & 0x7f80_0000) == 0x7f80_0000 && (bits & 0x007f_ffff) != 0
}

fn choice_constraint(
    sym: isla_lib::smt::Sym,
    choices: &[u64],
    width: u32,
) -> Exp<isla_lib::smt::Sym> {
    choices
        .iter()
        .copied()
        .map(|bits| {
            Exp::Eq(
                Box::new(Exp::Var(sym)),
                Box::new(Exp::Bits64(B64::new(bits, width))),
            )
        })
        .reduce(|left, right| Exp::Or(Box::new(left), Box::new(right)))
        .unwrap()
}

fn oracle_arithmetic(
    oracle: &str,
    op: &str,
    values: &[u64],
) -> Result<(u64, u64), Box<dyn std::error::Error>> {
    let mut command = std::process::Command::new(oracle);
    command.args(["--op", op, "--fmt", "f32", "--rm", &values[0].to_string()]);
    for (name, value) in ["a", "b", "c"].iter().zip(values[1..].iter()) {
        command
            .arg(format!("--{}", name))
            .arg(format!("0x{:08x}", value));
    }
    let output = command.output()?;
    if !output.status.success() {
        return Err(format!("SoftFloat oracle failed: {:?}", output).into());
    }
    let json: serde_json::Value = serde_json::from_slice(&output.stdout)?;
    let flags = parse_hex(json["flags"].as_str().ok_or("missing oracle flags")?)?;
    let bits = parse_hex(
        json["result_bits"]
            .as_str()
            .ok_or("missing oracle result")?,
    )?;
    Ok((flags, bits))
}

fn run_symbolic(
    initialized: &isla_lib::init::Initialized<B64>,
    oracle: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    for op in ["add", "sub", "div", "fma"] {
        let start = std::time::Instant::now();
        let choices: Vec<Vec<u64>> = match op {
            "add" | "sub" => vec![
                vec![0, 3],
                vec![0x3f80_0000, 0x7f7f_ffff],
                vec![0x3380_0000, 0x7f7f_ffff],
            ],
            "div" => vec![
                vec![0, 3],
                vec![0x3f80_0000, 0x7f7f_ffff],
                vec![0x0000_0000, 0x7f7f_ffff],
            ],
            "fma" => vec![
                vec![0, 3],
                vec![0x3f80_0000, 0x7f7f_ffff],
                vec![0x4000_0000, 0x7f7f_ffff],
                vec![0xbf80_0000, 0x7f80_0000],
            ],
            _ => unreachable!(),
        };
        let ctx = Context::new(Config::new());
        let mut solver = Solver::<B64>::new(&ctx);
        let symbols: Vec<_> = choices
            .iter()
            .enumerate()
            .map(|(index, _)| {
                solver.declare_const(
                    SmtTy::BitVec(if index == 0 { 3 } else { 32 }),
                    SourceLoc::unknown(),
                )
            })
            .collect();
        for (index, options) in choices.iter().enumerate() {
            solver.assert(choice_constraint(
                symbols[index],
                options,
                if index == 0 { 3 } else { 32 },
            ));
        }
        if !matches!(solver.check_sat(SourceLoc::unknown()), SmtResult::Sat) {
            return Err(format!("{} symbolic input constraints are not SAT", op).into());
        }
        let checkpoint = isla_lib::smt::checkpoint(&mut solver);
        let args: Vec<_> = symbols.iter().copied().map(Val::Symbolic).collect();
        let mut combinations: Vec<Vec<u64>> = vec![Vec::new()];
        for options in &choices {
            combinations = combinations
                .iter()
                .flat_map(|prefix| {
                    options.iter().map(|value| {
                        let mut next = prefix.clone();
                        next.push(*value);
                        next
                    })
                })
                .collect();
        }
        let expected: Vec<_> = combinations
            .iter()
            .map(|values| {
                let (flags, bits) = oracle_arithmetic(oracle, op, values)?;
                Ok::<_, Box<dyn std::error::Error>>((values.clone(), flags, bits, f32_nan(bits)))
            })
            .collect::<Result<_, _>>()?;
        let count = expected.len();
        let collected: Mutex<Vec<Result<(), String>>> = Mutex::new(Vec::new());
        execute_ir_function_with_checkpoint(
            &format!("zieee_{}32_probe", op),
            &args,
            &initialized.shared_state,
            &initialized.regs,
            &initialized.lets,
            &collected,
            &|_, _, run, state, mut solver, results| {
                let outcome = match run {
                    Ok((Run::Finished(value), _frame)) => {
                        if !matches!(solver.check_sat(SourceLoc::unknown()), SmtResult::Sat) {
                            Err("input path is not SAT".to_string())
                        } else if let Val::Struct(fields) = value {
                            let mut flag_exp = None;
                            let mut result_exp = None;
                            for (field, val) in &fields {
                                let converted = smt_value(val, SourceLoc::unknown())
                                    .map_err(|error| format!("{:?}", error));
                                if state.symtab.to_str(*field).ends_with('0') {
                                    flag_exp = Some(converted);
                                } else {
                                    result_exp = Some(converted);
                                }
                            }
                            let build = || -> Result<Exp<_>, String> {
                                let flags = flag_exp.ok_or("missing flags")??;
                                let result = result_exp.ok_or("missing result")??;
                                let mut correct = Exp::Bool(false);
                                for (inputs, expected_flags, expected_bits, skip_result) in
                                    &expected
                                {
                                    let mut condition = Exp::Bool(true);
                                    for (index, value) in inputs.iter().enumerate() {
                                        let width = if index == 0 { 3 } else { 32 };
                                        let match_input = Exp::Eq(
                                            Box::new(Exp::Var(symbols[index])),
                                            Box::new(Exp::Bits64(B64::new(*value, width))),
                                        );
                                        condition =
                                            Exp::And(Box::new(condition), Box::new(match_input));
                                    }
                                    let same_flags = Exp::Eq(
                                        Box::new(flags.clone()),
                                        Box::new(Exp::Bits64(B64::new(*expected_flags, 5))),
                                    );
                                    condition = Exp::And(Box::new(condition), Box::new(same_flags));
                                    if !skip_result {
                                        let same_result = Exp::Eq(
                                            Box::new(result.clone()),
                                            Box::new(Exp::Bits64(B64::new(*expected_bits, 32))),
                                        );
                                        condition =
                                            Exp::And(Box::new(condition), Box::new(same_result));
                                    }
                                    correct = Exp::Or(Box::new(correct), Box::new(condition));
                                }
                                Ok(correct)
                            };
                            match build() {
                                Ok(correct) => {
                                    solver.assert(Exp::Not(Box::new(correct)));
                                    match solver.check_sat(SourceLoc::unknown()) {
                                        SmtResult::Unsat => Ok(()),
                                        other => Err(format!(
                                            "symbolic counterexample or timeout: {:?}",
                                            other
                                        )),
                                    }
                                }
                                Err(error) => Err(error),
                            }
                        } else {
                            Err("probe returned no tuple".to_string())
                        }
                    }
                    Ok((_, _)) => Err("symbolic execution did not finish".to_string()),
                    Err((error, _)) => Err(format!("symbolic execution error: {:?}", error)),
                };
                results.lock().unwrap().push(outcome);
            },
            checkpoint,
            None,
        );
        let results = collected.into_inner().unwrap();
        if results.len() != 1 {
            return Err(format!("{} forked into {} paths", op, results.len()).into());
        }
        results.into_iter().next().unwrap()?;
        println!(
            "PASS symbolic {}: {} constrained combinations, one path, {} ms",
            op,
            count,
            start.elapsed().as_millis()
        );
    }
    Ok(())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    configure_tastic(Tactic::Qfaufbv);
    let ir_path = std::env::args()
        .nth(1)
        .ok_or("usage: probe IR_FILE < cases.txt")?;
    let prove = std::env::args().nth(2).as_deref() == Some("--prove");
    let ir = Box::leak(std::fs::read_to_string(ir_path)?.into_boxed_str());
    let mut symtab = Symtab::new();
    let definitions: Vec<Def<Name, B64>> = IrParser::new().parse(&mut symtab, new_ir_lexer(ir))?;
    let defs = Box::leak(definitions.into_boxed_slice());
    let type_info = IRTypeInfo::new(defs);
    let config = empty_config();
    let initialized = initialize_architecture(
        defs,
        symtab,
        type_info,
        &config,
        AssertionMode::Optimistic,
        false,
    );
    if std::env::args().nth(2).as_deref() == Some("--symbolic") {
        let oracle = std::env::args()
            .nth(3)
            .ok_or("usage: probe IR_FILE --symbolic SOFTFLOAT_ORACLE")?;
        return run_symbolic(&initialized, &oracle);
    }

    for (line_number, line) in io::stdin().lock().lines().enumerate() {
        let line = line?;
        if line.trim().is_empty() || line.starts_with('#') {
            continue;
        }
        let fields: Vec<_> = line.split_whitespace().collect();
        if fields.len() < 4 {
            return Err(format!("line {}: expected op width rm a [b c]", line_number + 1).into());
        }
        let op = fields[0];
        let comparison = ["eq", "eq_signaling", "lt", "lt_quiet", "le", "le_quiet"].contains(&op);
        let width: u32 = fields[1].parse()?;
        if ![16, 32, 64].contains(&width) {
            return Err("width must be 16, 32 or 64".into());
        }
        let rm = fields[2].parse::<u64>()?;
        let (name, argument_widths, result_width, use_rm) =
            if ["add", "sub", "mul", "div", "sqrt", "fma"].contains(&op) {
                let count = if op == "sqrt" {
                    1
                } else if op == "fma" {
                    3
                } else {
                    2
                };
                (
                    format!("zieee_{}{}_probe", op, width),
                    vec![width; count],
                    width,
                    true,
                )
            } else if comparison {
                (
                    format!("zieee_{}{}_probe", op, width),
                    vec![width; 2],
                    1,
                    false,
                )
            } else if op == "round" {
                (
                    format!("zieee_round{}_probe", width),
                    vec![width, 1],
                    width,
                    true,
                )
            } else if let Some(dst) = op.strip_prefix("fp_to_") {
                let (suffix, result_width) = match dst {
                    "i32" | "u32" | "fp32" => (dst.to_string(), 32),
                    "i64" | "u64" | "fp64" => (dst.to_string(), 64),
                    "fp16" | "bf16" => (dst.to_string(), 16),
                    _ => return Err("unsupported FP destination".into()),
                };
                let name = if suffix == "bf16" {
                    "zieee_fp32_to_bf16_probe".to_string()
                } else {
                    format!("zieee_fp{}_to_{}_probe", width, suffix)
                };
                (name, vec![width], result_width, true)
            } else if let Some(src) = op.strip_suffix("_to_fp") {
                let src_width = if src.ends_with("32") {
                    32
                } else if src.ends_with("64") {
                    64
                } else {
                    return Err("unsupported integer source".into());
                };
                (
                    format!("zieee_{}_to_fp{}_probe", src, width),
                    vec![src_width],
                    width,
                    true,
                )
            } else if op == "rod" {
                let dst_width = if width == 32 {
                    16
                } else if width == 64 {
                    32
                } else {
                    return Err("unsupported ROD source".into());
                };
                (
                    format!("zieee_rod{}_probe", width),
                    vec![width],
                    dst_width,
                    false,
                )
            } else {
                return Err(
                    format!("line {}: unsupported operation {}", line_number + 1, op).into(),
                );
            };
        let operand_count = argument_widths.len();
        let expected_fields = 3 + operand_count + if prove { 3 } else { 0 };
        if fields.len() != expected_fields {
            return Err(format!("line {}: wrong number of fields", line_number + 1).into());
        }
        let mut args = if use_rm {
            vec![Val::Bits(B64::new(rm, 3))]
        } else {
            vec![]
        };
        for (operand, bit_width) in fields[3..3 + operand_count]
            .iter()
            .zip(argument_widths.iter())
        {
            args.push(Val::Bits(B64::new(parse_hex(operand)?, *bit_width)));
        }
        let oracle = if prove {
            Some((
                parse_hex(fields[3 + operand_count])?,
                parse_hex(fields[4 + operand_count])?,
                fields[5 + operand_count] == "1",
            ))
        } else {
            None
        };
        let result: Mutex<Vec<Result<(u64, u64), String>>> = Mutex::new(Vec::new());
        execute_ir_function(
            &name,
            &args,
            &initialized.shared_state,
            &initialized.regs,
            &initialized.lets,
            &result,
            &|_, _, run, state, mut solver, collected| {
                let observed = match run {
                    Ok((Run::Finished(value), _frame)) => match solver
                        .check_sat(SourceLoc::unknown())
                    {
                        SmtResult::Sat => {
                            let sampled = {
                                let mut model = Model::new(&solver);
                                model
                                    .get_val(&value)
                                    .map_err(|e| format!("model: {:?}", e))
                                    .and_then(bits_pair)
                            };
                            sampled.and_then(|(flags, bits)| {
                                if let Some((expected_flags, expected_bits, skip_result)) = oracle {
                                    prove_unique(
                                        &value,
                                        expected_flags,
                                        expected_bits,
                                        result_width,
                                        comparison,
                                        skip_result,
                                        state,
                                        &mut solver,
                                    )?;
                                }
                                Ok((flags, bits))
                            })
                        }
                        other => Err(format!("SMT result: {:?}", other)),
                    },
                    Ok((_, _frame)) => Err("execution did not finish".into()),
                    Err((error, _frame)) => Err(format!("execution error: {:?}", error)),
                };
                collected.lock().unwrap().push(observed);
            },
        );
        let results = result.into_inner().unwrap();
        if results.len() != 1 {
            return Err(format!(
                "line {}: expected one path, got {}",
                line_number + 1,
                results.len()
            )
            .into());
        }
        let (flags, bits) = results.into_iter().next().unwrap()?;
        println!(
            "0x{:02x} 0x{:0width$x}",
            flags,
            bits,
            width = ((result_width + 3) / 4) as usize
        );
    }
    Ok(())
}
