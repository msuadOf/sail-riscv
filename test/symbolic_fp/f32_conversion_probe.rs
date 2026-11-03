// Run one production Sail helper per line and prove its bits and flags unique.
use isla_lib::bitvector::{b64::B64, BV};
use isla_lib::config::{ISAConfig, Tool};
use isla_lib::executor::{execute_ir_function, Run};
use isla_lib::init::initialize_architecture;
use isla_lib::ir::{AssertionMode, IRTypeInfo, Name, Symtab, Val};
use isla_lib::ir_lexer::new_ir_lexer;
use isla_lib::ir_parser::IrParser;
use isla_lib::primop_util::smt_value;
use isla_lib::smt::smtlib::Exp;
use isla_lib::smt::{configure_tastic, SmtResult, Tactic};
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
        assembler: empty_tool(), objdump: empty_tool(), nm: empty_tool(), linker: empty_tool(),
        page_table_base: 0, page_size: 0, s2_page_table_base: 0, s2_page_size: 0,
        default_page_table_setup: String::new(),
        thread_base: 0, thread_top: 0, thread_stride: 0,
        symbolic_addr_base: 0, symbolic_addr_top: 0, symbolic_addr_stride: 0,
        default_registers: HashMap::new(), reset_registers: Vec::new(),
        reset_constraints: Vec::new(), const_primops: HashMap::new(),
        function_assumptions: Vec::new(), register_renames: HashMap::new(),
        ignored_registers: HashSet::new(), relaxed_registers: HashSet::new(),
        probes: HashSet::new(), probe_functions: HashSet::new(),
        trace_functions: HashSet::new(), translation_function: None,
        in_program_order: HashSet::new(), default_sizeof: 0,
        zero_announce_exit: false, memory_regions: None, page_table_config: None,
        pmp: None, clint_enabled: None, execution_limits: None,
    }
}

fn parse_hex(s: &str) -> Result<u64, Box<dyn std::error::Error>> {
    Ok(u64::from_str_radix(s.strip_prefix("0x").unwrap_or(s), 16)?)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    configure_tastic(Tactic::Qfaufbv);
    let ir_path = std::env::args().nth(1).ok_or("usage: f32_conversion_probe IR_FILE < cases")?;
    let ir = Box::leak(std::fs::read_to_string(ir_path)?.into_boxed_str());
    let mut symtab = Symtab::new();
    let definitions = IrParser::new().parse(&mut symtab, new_ir_lexer(ir))?;
    let type_info = IRTypeInfo::new(&definitions);
    let definitions = Box::leak(definitions.into_boxed_slice());
    let initialized = initialize_architecture(definitions, symtab, type_info, &empty_config(), AssertionMode::Optimistic, false);

    if std::env::args().nth(2).as_deref() == Some("--unknown") {
        let helpers = [
            "riscv_f32Eq", "riscv_f32Lt", "riscv_f32Lt_quiet", "riscv_f32Le", "riscv_f32Le_quiet",
            "riscv_f32Add", "riscv_f32Sub", "riscv_f32Mul", "riscv_f32Div", "riscv_f32Sqrt",
            "riscv_f32MulAdd", "riscv_f32roundToInt", "riscv_f32ToI32", "riscv_f32ToUi32",
            "riscv_f32ToI64", "riscv_f32ToUi64", "riscv_i32ToF32", "riscv_ui32ToF32",
            "riscv_i64ToF32", "riscv_ui64ToF32", "riscv_f32ToF16", "riscv_f32ToF64",
            "riscv_f32ToBF16",
        ];
        for helper in helpers {
            let paths = Mutex::new(Vec::new());
            execute_ir_function(
                &format!("zf32_unknown_{helper}"), &[], &initialized.shared_state,
                &initialized.regs, &initialized.lets, &paths,
                &|_, _, result, _, mut solver, paths| {
                    let status = match result {
                        Ok((Run::Finished(_), _)) => solver.check_sat(SourceLoc::unknown()),
                        Ok((_, _)) => SmtResult::Unknown,
                        Err((_, _)) => SmtResult::Unknown,
                    };
                    paths.lock().unwrap().push(status);
                },
            );
            let paths = paths.into_inner().unwrap();
            if paths != [SmtResult::Sat] {
                return Err(format!("unknown-input {helper}: expected one SAT completed path, got {paths:?}").into());
            }
            println!("PASS unknown-input {helper}: one SAT completed path");
        }
        return Ok(());
    }

    for (index, line) in io::stdin().lock().lines().enumerate() {
        let line = line?;
        if line.trim().is_empty() || line.starts_with('#') { continue; }
        let fields: Vec<_> = line.split_whitespace().collect();
        if fields.len() != 8 { return Err(format!("line {}: expected 8 fields", index + 1).into()); }
        let name = fields[0];
        let input_width: u32 = fields[1].parse()?;
        let result_width: u32 = fields[2].parse()?;
        let rm: u64 = fields[3].parse()?;
        let input = parse_hex(fields[4])?;
        let exact: bool = fields[5] == "1";
        let expected_flags = parse_hex(fields[6])?;
        let expected_bits = parse_hex(fields[7])?;
        let mut args = vec![Val::Bits(B64::new(rm, 3)), Val::Bits(B64::new(input, input_width))];
        if name == "riscv_f32roundToInt" { args.push(Val::Bool(exact)); }
        let results = Mutex::new(Vec::new());
        execute_ir_function(
            &format!("z{name}"), &args, &initialized.shared_state,
            &initialized.regs, &initialized.lets, &results,
            &|_, _, result, state, mut solver, collected| {
                let proof = (|| -> Result<(), String> {
                    let (Run::Finished(value), _) = result.map_err(|(e, _)| format!("execution: {e:?}"))?
                    else { return Err("execution did not finish".into()); };
                    if solver.check_sat(SourceLoc::unknown()) != SmtResult::Sat {
                        return Err("input is not SAT".into());
                    }
                    let Val::Struct(parts) = value else { return Err("expected tuple".into()); };
                    let mut flags = None;
                    let mut bits = None;
                    for (field, value) in parts {
                        let term = smt_value(&value, SourceLoc::unknown()).map_err(|e| format!("SMT value: {e:?}"))?;
                        if state.symtab.to_str(field).ends_with('0') { flags = Some(term); }
                        else { bits = Some(term); }
                    }
                    let flags = flags.ok_or("missing flags")?;
                    let bits = bits.ok_or("missing bits")?;
                    let mismatch = Exp::Or(
                        Box::new(Exp::Neq(Box::new(flags), Box::new(Exp::Bits64(B64::new(expected_flags, 5))))),
                        Box::new(Exp::Neq(Box::new(bits), Box::new(Exp::Bits64(B64::new(expected_bits, result_width))))),
                    );
                    solver.assert(mismatch);
                    match solver.check_sat(SourceLoc::unknown()) {
                        SmtResult::Unsat => Ok(()),
                        other => Err(format!("result or flags differ: {other:?}")),
                    }
                })();
                collected.lock().unwrap().push(proof);
            },
        );
        let results = results.into_inner().unwrap();
        if results.len() != 1 { return Err(format!("line {}: {} paths", index + 1, results.len()).into()); }
        results.into_iter().next().unwrap().map_err(|e| format!("line {} {}: {e}", index + 1, name))?;
        println!("PASS {name} rm={rm} input={input:#x}");
    }
    Ok(())
}
