use isla_lib::bitvector::{b64::B64, BV};
use isla_lib::config::{ISAConfig, Tool};
use isla_lib::executor::{execute_ir_function, Run};
use isla_lib::init::initialize_architecture;
use isla_lib::ir::{AssertionMode, Def, IRTypeInfo, Name, Symtab, Val};
use isla_lib::ir_lexer::new_ir_lexer;
use isla_lib::ir_parser::IrParser;
use isla_lib::primop_util::smt_value;
use isla_lib::smt::{configure_tastic, Model, SmtResult, Tactic};
use isla_lib::smt::smtlib::Exp;
use isla_lib::source_loc::SourceLoc;
use std::collections::{HashMap, HashSet};
use std::io::{self, BufRead};
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

fn bits_pair(value: Val<B64>) -> Result<(u64, u64), String> {
    let Val::Struct(fields) = value else { return Err("probe did not return a tuple".into()) };
    let mut flags = None;
    let mut result = None;
    for field in fields.into_values() {
        match field {
            Val::Bits(bits) if bits.len() == 5 => flags = Some(bits.lower_u64()),
            Val::Bits(bits) => result = Some(bits.lower_u64()),
            Val::Bool(value) => result = Some(u64::from(value)),
            other => return Err(format!("unexpected tuple field: {other:?}")),
        }
    }
    Ok((flags.ok_or("missing flags")?, result.ok_or("missing result")?))
}

fn parse_hex(s: &str) -> Result<u64, String> {
    u64::from_str_radix(s.strip_prefix("0x").unwrap_or(s), 16).map_err(|e| e.to_string())
}

fn prove_unknown(
    value: &Val<B64>, inputs: &[Val<B64>], flags: u64, bits: u64, width: u32,
    state: &isla_lib::ir::SharedState<B64>, solver: &mut isla_lib::smt::Solver<B64>,
) -> Result<(u64, u64), String> {
    let Val::Struct(fields) = value else { return Err("unknown probe did not return tuple".into()) };
    let mut ordered: Vec<_> = fields.iter().collect();
    ordered.sort_by_key(|(name, _)| state.symtab.to_str(**name));
    if ordered.len() != inputs.len() + 2 { return Err("unknown probe tuple has wrong size".into()); }
    let mut conditions = Exp::Bool(true);
    for (actual, expected) in ordered.iter().take(inputs.len()).zip(inputs) {
        let lhs = smt_value(actual.1, SourceLoc::unknown()).map_err(|e| format!("SMT input: {e:?}"))?;
        let rhs = smt_value(expected, SourceLoc::unknown()).map_err(|e| format!("expected input: {e:?}"))?;
        conditions = Exp::And(Box::new(conditions), Box::new(Exp::Eq(Box::new(lhs), Box::new(rhs))));
    }
    if solver.check_sat_with(&conditions, SourceLoc::unknown()) != SmtResult::Sat {
        return Err("constrained symbolic inputs are unreachable".into());
    }
    solver.assert(conditions);
    let actual_flags = smt_value(ordered[inputs.len()].1, SourceLoc::unknown()).map_err(|e| format!("SMT flags: {e:?}"))?;
    let actual_result = smt_value(ordered[inputs.len() + 1].1, SourceLoc::unknown()).map_err(|e| format!("SMT result: {e:?}"))?;
    let expected_result = if width == 1 { Exp::Bool(bits != 0) }
        else { Exp::Bits64(B64::new(bits, width)) };
    let mismatch = Exp::Or(
        Box::new(Exp::Neq(Box::new(actual_flags), Box::new(Exp::Bits64(B64::new(flags, 5))))),
        Box::new(Exp::Neq(Box::new(actual_result), Box::new(expected_result))),
    );
    solver.assert(mismatch);
    if solver.check_sat(SourceLoc::unknown()) != SmtResult::Unsat {
        return Err("constrained symbolic result or flags can differ".into());
    }
    Ok((flags, bits))
}

fn prove_unique(
    value: &Val<B64>, flags: u64, bits: u64, width: u32, skip_result: bool,
    state: &isla_lib::ir::SharedState<B64>, solver: &mut isla_lib::smt::Solver<B64>,
) -> Result<(), String> {
    let Val::Struct(fields) = value else { return Err("probe did not return tuple".into()) };
    let mut flag_exp = None;
    let mut result_exp = None;
    for (field, value) in fields {
        let exp = smt_value(value, SourceLoc::unknown()).map_err(|e| format!("SMT value: {:?}", e))?;
        if state.symtab.to_str(*field).ends_with('0') { flag_exp = Some(exp); }
        else { result_exp = Some(exp); }
    }
    let different_flags = Exp::Neq(Box::new(flag_exp.ok_or("missing flags")?), Box::new(Exp::Bits64(B64::new(flags, 5))));
    let mismatch = if skip_result {
        different_flags
    } else {
        let expected = if width == 1 { Exp::Bool(bits != 0) }
            else { Exp::Bits64(B64::new(bits, width)) };
        let different_result = Exp::Neq(Box::new(result_exp.ok_or("missing result")?), Box::new(expected));
        Exp::Or(Box::new(different_flags), Box::new(different_result))
    };
    solver.assert(mismatch);
    match solver.check_sat(SourceLoc::unknown()) {
        SmtResult::Unsat => Ok(()),
        other => Err(format!("non-unique flags/result: {:?}", other)),
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    configure_tastic(Tactic::Qfaufbv);
    let ir_path = std::env::args().nth(1).ok_or("usage: probe IR_FILE < cases.txt")?;
    let ir = Box::leak(std::fs::read_to_string(ir_path)?.into_boxed_str());
    let mut symtab = Symtab::new();
    let definitions: Vec<Def<Name, B64>> = IrParser::new().parse(&mut symtab, new_ir_lexer(ir))?;
    let defs = Box::leak(definitions.into_boxed_slice());
    let type_info = IRTypeInfo::new(defs);
    let config = empty_config();
    let initialized = initialize_architecture(defs, symtab, type_info, &config, AssertionMode::Optimistic, false);

    for (line_number, line) in io::stdin().lock().lines().enumerate() {
        let line = line?;
        if line.trim().is_empty() || line.starts_with('#') { continue; }
        let fields: Vec<_> = line.split_whitespace().collect();
        if fields.len() < 7 { return Err(format!("line {}: name width flags bits skip count operands", line_number + 1).into()); }
        let name = format!("z{}", fields[0]);
        let result_width: u32 = fields[1].parse()?;
        let expected_flags = parse_hex(fields[2])?;
        let expected_bits = parse_hex(fields[3])?;
        let skip_result = fields[4] == "1";
        let operand_count: usize = fields[5].parse()?;
        if fields.len() != 6 + operand_count { return Err(format!("line {}: wrong operand count", line_number + 1).into()); }
        let mut args = Vec::new();
        for operand in &fields[6..] {
            let (kind, raw) = operand.split_once(':').ok_or("operand must be WIDTH:HEX or b:0/1")?;
            if kind == "b" {
                args.push(Val::Bool(raw == "1"));
            } else {
                let width: u32 = kind.parse()?;
                args.push(Val::Bits(B64::new(parse_hex(raw)?, width)));
            }
        }
        let unknown = name.starts_with("zf16_wrapper_unknown_");
        let result: Mutex<Vec<Result<(u64, u64), String>>> = Mutex::new(Vec::new());
        execute_ir_function(
            &name, if unknown { &[] } else { &args },
            &initialized.shared_state, &initialized.regs, &initialized.lets,
            &result,
            &|_, _, run, state, mut solver, collected| {
                let observed = match run {
                    Ok((Run::Finished(value), _frame)) => match solver.check_sat(SourceLoc::unknown()) {
                        SmtResult::Sat => {
                            if unknown {
                                prove_unknown(&value, &args, expected_flags, expected_bits,
                                    result_width, state, &mut solver)
                            } else {
                            let sampled = {
                                let mut model = Model::new(&solver);
                                model.get_val(&value).map_err(|e| format!("model: {:?}", e)).and_then(bits_pair)
                            };
                            sampled.and_then(|(flags, bits)| {
                                prove_unique(&value, expected_flags, expected_bits, result_width, skip_result, state, &mut solver)?;
                                Ok((flags, bits))
                            })
                            }
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
        if results.len() != 1 { return Err(format!("line {}: expected one path, got {}", line_number + 1, results.len()).into()); }
        let (flags, bits) = results.into_iter().next().unwrap()?;
        if flags != expected_flags || (!skip_result && bits != expected_bits) {
            return Err(format!("line {}: {} got flags={:#x} bits={:#x}; expected flags={:#x} bits={:#x}",
                line_number + 1, name, flags, bits, expected_flags, expected_bits).into());
        }
        println!("{} flags={:#x} bits={:#x} one_path SAT/UNSAT", name, flags, bits);
    }
    Ok(())
}
