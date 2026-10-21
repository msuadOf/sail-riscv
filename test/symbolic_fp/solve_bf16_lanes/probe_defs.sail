type bits_fflags = bits(5)

function nvFlag() -> bits_fflags = 0b10000
function canonical_NaN_S() -> bits(32) = 0x7fc00000
function fmake_S(sign : bits(1), exp : bits(8), mant : bits(23)) -> bits(32) = sign @ exp @ mant
function accrue_fflags(_flags : bits_fflags) -> unit = ()
