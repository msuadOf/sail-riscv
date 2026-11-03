// Keep the former conversion body as an independent comparison target.
function old_bf16_to_f32(v : bits(16)) -> (bits_fflags, bits(32)) = {
  let (sign, exp, mant) = fsplit_BF16(v);
  let is_nan = exp == ones() & mant != zeros();
  let is_inf = exp == ones() & mant == zeros();
  let flags = if is_nan & signed(mant) >= 0 then nvFlag() else zeros();
  let value = if is_nan then canonical_NaN_S()
    else if is_inf then fmake_S(sign, ones(), zeros())
    else fmake_S(sign, exp, mant @ zeros(16));
  (flags, value)
}

function bf16_unknown_equivalence() -> (bits(16), bits_fflags, bits(32), bits_fflags, bits(32)) = {
  let v : bits(16) = undefined;
  let (old_flags, old_bits) = old_bf16_to_f32(v);
  let (new_flags, new_bits) = bf16_to_f32(v);
  (v, old_flags, old_bits, new_flags, new_bits)
}

function bf16_unknown_new() -> (bits(16), bits_fflags, bits(32)) = {
  let v : bits(16) = undefined;
  let (flags, bits) = bf16_to_f32(v);
  (v, flags, bits)
}
