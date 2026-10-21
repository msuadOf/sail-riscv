// =======================================================================================
// This Sail RISC-V architecture model is subject to the BSD two-clause license.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

$sail_internal

val ite = pure {c: "ite"} : forall ('a : Type). (bool, 'a, 'a) -> 'a
val strict_and_bool = pure {c: "strict_and_bool"} : (bool, bool) -> bool
val strict_or_bool = pure {c: "strict_or_bool"} : (bool, bool) -> bool
val isla_bool_to_bit = pure {c: "isla_bool_to_bit"} : bool -> bit
// Candidate pure Sail bodies; append after the four c-only val declarations during P1 review.
function ite(condition, yes, no) = if condition then yes else no
function strict_and_bool(lhs, rhs) = lhs & rhs
function strict_or_bool(lhs, rhs) = lhs | rhs
function isla_bool_to_bit(value) = if value then 0b1 else 0b0

