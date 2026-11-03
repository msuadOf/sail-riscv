use isla_lib::bitvector::{b64::B64, BV};
use isla_lib::config::{ISAConfig, Tool};
use isla_lib::executor::{execute_ir_function, Run};
use isla_lib::init::initialize_architecture;
use isla_lib::ir::{AssertionMode, Name, Symtab, Val};
use isla_lib::ir_lexer::new_ir_lexer;
use isla_lib::ir_parser::IrParser;
use isla_lib::smt::{configure_tastic, Model, SmtResult, Tactic};
use isla_lib::source_loc::SourceLoc;
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::Mutex;

fn empty_config() -> ISAConfig<B64> {
    let tool = || Tool {
        executable: PathBuf::new(),
        options: Vec::new(),
    };
    ISAConfig {
        pc: Name::from_u32(u32::MAX),
        register_event_sets: HashMap::new(),
        assembler: tool(),
        objdump: tool(),
        nm: tool(),
        linker: tool(),
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

fn run(
    name: &str,
    args: &[Val<B64>],
    state: &isla_lib::init::Initialized<'_, B64>,
    expected: Option<u64>,
) -> Result<(), String> {
    let observations = Mutex::new(Vec::<Result<u64, String>>::new());
    execute_ir_function(
        name,
        args,
        &state.shared_state,
        &state.regs,
        &state.lets,
        &observations,
        &|_, _, result, _, mut solver, values| {
            let observed = match result {
                Ok((Run::Finished(value), _)) => {
                    if solver.check_sat(SourceLoc::unknown()) != SmtResult::Sat {
                        Err("path is not SAT".to_string())
                    } else {
                        let mut model = Model::new(&solver);
                        match model.get_val(&value) {
                            Ok(Val::Bits(bits)) => Ok(bits.lower_u64()),
                            other => Err(format!("unexpected result: {other:?}")),
                        }
                    }
                }
                Ok(_) => Err("path did not finish".to_string()),
                Err((error, _)) => Err(format!("execution error: {error:?}")),
            };
            values.lock().unwrap().push(observed);
        },
    );
    let observed = observations.into_inner().unwrap();
    if observed.len() != 1 {
        return Err(format!("{name}: expected one path, got {}", observed.len()));
    }
    let value = observed.into_iter().next().unwrap()?;
    if let Some(expected) = expected {
        if value != expected {
            return Err(format!("{name}: got {value:#x}, expected {expected:#x}"));
        }
    }
    Ok(())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    configure_tastic(Tactic::Qfaufbv);
    let ir_path = std::env::args()
        .nth(1)
        .ok_or("usage: type_reuse_probe IR")?;
    let ir = Box::leak(std::fs::read_to_string(ir_path)?.into_boxed_str());
    let mut symtab = Symtab::new();
    let mut defs = IrParser::new().parse(&mut symtab, new_ir_lexer(ir))?;
    let type_info = isla_lib::ir::IRTypeInfo::new(&defs);
    let state = initialize_architecture(
        &mut defs,
        symtab,
        type_info,
        &empty_config(),
        AssertionMode::Optimistic,
        false,
    );

    // Expected ISA bits are computed independently from shared Sail bit order.
    for mask in 0u64..32 {
        let facts = (0..5)
            .map(|bit| Val::Bool((mask & (1 << bit)) != 0))
            .collect::<Vec<_>>();
        let riscv = ((mask & 1) << 4)
            | ((mask & 2) << 2)
            | (mask & 4)
            | ((mask & 8) >> 2)
            | ((mask & 16) >> 4);
        run(
            "ztype_reuse_flags",
            &facts,
            &state,
            Some((mask << 5) | riscv),
        )?;
    }
    println!("32 shared flag combinations and ISA bit mappings PASS");

    for (width, exp_bits, frac_bits) in [(16, 5, 10), (32, 8, 23), (64, 11, 52)] {
        let sign = 1u64 << (width - 1);
        let exp = ((1u64 << exp_bits) - 1) << frac_bits;
        let quiet = 1u64 << (frac_bits - 1);
        let cases = [
            (0, 3),
            (sign, 3), // signed zero: zero and finite
            (1, 1),
            (sign | 1, 1), // subnormal
            (1u64 << frac_bits, 1),
            (sign | (1u64 << frac_bits), 1), // normal
            (exp, 4),
            (sign | exp, 4), // infinity
            (exp | 1, 24),
            (sign | exp | 1, 24), // signaling NaN
            (exp | quiet, 16),
            (sign | exp | quiet, 16), // quiet NaN
        ];
        for (bits, expected) in cases {
            run(
                &format!("ztype_reuse_classify{width}"),
                &[Val::Bits(B64::new(bits, width))],
                &state,
                Some(expected),
            )?;
        }
        run(&format!("ztype_reuse_unknown{width}"), &[], &state, None)?;
        println!("f{width}: 12 special values and one unknown input path PASS");
    }
    Ok(())
}
