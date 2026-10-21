# AMO complete layout probe

`build_fixture.py` extracts the production `amo_layout` and original `encdec_amoop` mapping into one small Sail source. It builds separate non-E and E fixtures. Each fixture places the old concatenated layout and new tuple layout in the same IR, then compares their top mappings.

The runner proves, for an unknown full 32-bit input, equality of old and new backward matches and complete decoded constructor/payload. It checks re-encoding and forward matches on every accepted input. Because every typed AMO payload encodes to an accepted word in the corresponding register domain, this also covers the finite typed tuple domain. It separately compares forward encoding and matches on an unknown raw `%i64` width value, including values outside `{1,2,4,8,16}`; the original width mapping falls back to `100` for those raw values. The runner checks concrete invalid opcode, op, width, and E-register value calls, ten operations across five widths, and non-AMO forward matches.

The fixture's `fixture_guard` is a sentinel for guard sequencing: width 1 returns false and odd-register AMOCAS width 16 asserts. It tests old and new mapping fallthrough and the invalid-opcode negative control. It does **not** reproduce the full `amo_encoding_valid` implementation. The real model IR must be reviewed separately for its top matcher → payload value → guard order, other-clause fallthrough, and forward guard → width encoder order.

The small IR explicitly preserves `_forwards_matches` functions for testing. Those functions may be absent from the production IR unless used there; this test does not claim they are production entry points.

Use `build_fixture.py --source model/extensions/A/zaamo_insts.sail --output <output.sail> [--e-mode]` from `sail-riscv/`. Compile the generated source with the Sail Isla plugin and preserve the functions listed in `isla/target/float-solve-evidence/amo-layout-20260927/manifest.json`. Compile `runner.rs` against the pinned `isla_lib` library in that manifest, then run `runner <fixture.ir> non_e` or `runner <fixture.ir> e`. `check_ir.py <fixture.ir>` verifies the matcher structure.
