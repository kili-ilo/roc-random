## PCG algorithms, constants, and wrappers
##
## For more information about PCG see [www.pcg-random.org](https://www.pcg-random.org)
##
## PCG is a family of simple fast space-efficient statistically good algorithms for random number generation.
##
AlgorithmConstants : {
	permute_multiplier : U32,
	permute_random_xor_shift : U32,
	permute_random_xor_shift_increment : U32,
	permute_xor_shift : U32,
	update_increment : U32,
	update_multiplier : U32,
}

Random := [].{

	# This implementation is based on this paper [PCG: A Family of Simple Fast Space-Efficient Statistically Good Algorithms for Random Number Generation](https://www.pcg-random.org/pdf/hmc-cs-2014-0905.pdf)
	# and this C++ header: [pcg_variants.h](https://github.com/imneme/pcg-c/blob/master/include/pcg_variants.h).
	#
	# Original Roc implementation by [JanCVanB](https://github.com/JanCVanB), January 2022
	#
	# Abbreviations:
	# - M = Multiplication (see section 6.3.4 on page 45 in the paper)
	# - PCG = Permuted Congruential Generator
	# - RXS = Random XorShift (see section 5.5.1 on page 36 in the paper)
	# - XS = XorShift (see section 5.5 on page 34 in the paper)

	## A generator that produces pseudorandom `value`s using the PCG algorithm.
	##
	## ```
	## rgb_generator : Generator({ red: U8, green: U8, blue: U8 })
	## rgb_generator =
	##     {
	##         red: Random.u8,
	##         green: Random.u8,
	##         blue: Random.u8,
	##     }.Random
	## ```
	Generator(value) : State -> Generation(value)

	## A pseudorandom value, paired with its `Generator`'s output state.
	##
	## This is required to chain multiple calls together passing the updated state.
	Generation(value) : { value : value, state : State }

	## Internal state for Generators
	State :: { s : U32, c : AlgorithmConstants }

	## Construct an initial "seed" `State` for `Generator`s
	seed : U32 -> State
	seed = |s| seed_variant(s, default_u32_update_increment)

	## Construct a specific "variant" of a "seed" for more advanced use.
	##
	## A "seed" is an initial `State` for `Generator`s.
	##
	## A "variant" is a `State` that specifies an `update_increment` constant,
	## to produce a sequence of internal `value`s that shares no consecutive pairs
	## with other variants of the same `State`.
	##
	## Odd numbers are recommended for the update increment,
	## to double the repetition period of sequences (by hitting odd values).
	seed_variant : U32, U32 -> State
	seed_variant = |s, u_i| {
		c = {
			permute_multiplier: default_u32_permute_multiplier,
			permute_random_xor_shift: default_u32_permute_random_xor_shift,
			permute_random_xor_shift_increment: default_u32_permute_random_xor_shift_increment,
			permute_xor_shift: default_u32_permute_xor_shift,
			update_increment: u_i,
			update_multiplier: default_u32_update_multiplier,
		}

		State.({ s, c })
	}

	## Generate a `Generation` from a state
	step : State, Generator(value) -> Generation(value)
	step = |s, g| g(s)

	## Generate a new `Generation` from an old `Generation`'s state
	next : Generation(_), Generator(value) -> Generation(value)
	next = |x, g| g(x.state)

	## Create a `Generator` that always returns the same thing.
	static : value -> Generator(value)
	static = |value|
		|state| { value, state }

	## Map over the value of a `Generator`.
	map : Generator(a), (a -> b) -> Generator(b)
	map = |generator, mapper|
		|state| {
			{ value, state: state2 } = generator(state)

			{ value: mapper(value), state: state2 }
		}

	## Compose two `Generator`s into a single `Generator`.
	##
	## This is the applicative operation used by Roc's record-builder syntax:
	##
	## ```
	## date_generator =
	##     {
	##         year: Random.bounded_i32(1, 2500),
	##         month: Random.bounded_i32(1, 12),
	##         day: Random.bounded_i32(1, 31),
	##     }.Random
	## ```
	map2 : Generator(a), Generator(b), (a, b -> c) -> Generator(c)
	map2 = |first_generator, second_generator, combiner|
		|state| {
			{ value: first, state: state2 } = first_generator(state)
			{ value: second, state: state3 } = second_generator(state2)

			{ value: combiner(first, second), state: state3 }
		}

	## Compose two `Generator`s into a single `Generator`.
	##
	## This is an alias for `map2`; record-builder syntax calls `map2` directly.
	chain : Generator(a), Generator(b), (a, b -> c) -> Generator(c)
	chain = map2

	## Generate a list of random values.
	## ```
	## generate_10_random_u8s : Generator(List(U8))
	## generate_10_random_u8s =
	##     Random.list(Random.u8, 10)
	## ```
	list : Generator(a), U64 -> Generator(List(a))
	list = |generator, length|
		|initial_state| {
			Iter.fold(
				0..<length,
				{ state: initial_state, value: [] },
				|prev, _| {
					{ value, state } = Random.step(prev.state, generator)
					{ state, value: prev.value.append(value) }
				},
			)
		}

	## Construct a `Generator` for 8-bit unsigned integers
	## NOTE: We are just taking the bottom 8 bits of the generated `U32` value
	## Some backing generators have worse statistical properties in the low-order bits
	## and it would be wise to use the upper 8 bits instead, but according to the pcg
	## paper (M.E. O'Neill) this backing generator has good statistical quality throughout
	## all the bits (perhaps from the good high bits being rotated/shifted around etc)
	u8 : Generator(U8)
	u8 = u32->map(U32.to_u8_wrap)

	## Construct a `Generator` for 8-bit unsigned integers between two boundaries (inclusive)
	bounded_u8 : U8, U8 -> Generator(U8)
	bounded_u8 = |x, y| {
		x_u32 = x.to_u32()
		y_u32 = y.to_u32()

		bounded_u32(x_u32, y_u32)->map(U32.to_u8_wrap)
	}

	## Construct a `Generator` for 8-bit signed integers
	i8 : Generator(I8)
	i8 = u32->map(U32.to_i8_wrap)

	## Construct a `Generator` for 8-bit signed integers between two boundaries (inclusive)
	bounded_i8 : I8, I8 -> Generator(I8)
	bounded_i8 = |x, y| {
		x_i32 = x.to_i32()
		y_i32 = y.to_i32()

		bounded_i32(x_i32, y_i32)->map(I32.to_i8_wrap)
	}

	## Construct a `Generator` for 16-bit unsigned integers
	u16 : Generator(U16)
	u16 = u32->map(U32.to_u16_wrap)

	## Construct a `Generator` for 16-bit unsigned integers between two boundaries (inclusive)
	bounded_u16 : U16, U16 -> Generator(U16)
	bounded_u16 = |x, y| {
		x_u32 = x.to_u32()
		y_u32 = y.to_u32()

		bounded_u32(x_u32, y_u32)->map(U32.to_u16_wrap)
	}

	## Construct a `Generator` for 16-bit signed integers
	i16 : Generator(I16)
	i16 = u32->map(U32.to_i16_wrap)

	## Construct a `Generator` for 16-bit signed integers between two boundaries (inclusive)
	bounded_i16 : I16, I16 -> Generator(I16)
	bounded_i16 = |x, y| {
		x_i32 = x.to_i32()
		y_i32 = y.to_i32()

		bounded_i32(x_i32, y_i32)->map(I32.to_i16_wrap)
	}

	## Construct a `Generator` for 32-bit unsigned integers
	u32 : Generator(U32)
	u32 = |s| {
		value = permute(s)
		state = update(s)

		{ value, state }
	}

	## Construct a `Generator` for 32-bit unsigned integers between two boundaries (inclusive)
	bounded_u32 : U32, U32 -> Generator(U32)
	bounded_u32 = |x, y| {
		(minimum, maximum) = sort(x, y)

		range = match (maximum - minimum).add_try(1) {
			Ok(r) => r
			# If absolute range doesn't fit in a U32 we need the full range generator
			Err(Overflow) => return Random.u32
		}

		|state| {
			offset = state->u32_exclusive_range_unbiased(range)

			value = minimum + offset.value

			{ value, state: offset.state }
		}
	}

	## Construct a `Generator` for 32-bit signed integers
	i32 : Generator(I32)
	i32 = u32->map(U32.to_i32_wrap)

	## Construct a `Generator` for 32-bit signed integers between two boundaries (inclusive)
	bounded_i32 : I32, I32 -> Generator(I32)
	bounded_i32 = |x, y| {
		(minimum, maximum) = sort(x, y)
		range = match I32.abs_diff(maximum, minimum).add_try(1) {
			Ok(r) => r
			# If absolute range doesn't fit in a U32 we need the full range generator
			Err(Overflow) => return Random.i32
		}

		|state| {
			offset = state->u32_exclusive_range_unbiased(range)
			offset_i32 = offset.value.to_i32_wrap()
			value = add_wrap_i32(minimum, offset_i32)

			{ value, state: offset.state }
		}
	}
}

# Helpers for the above constructors -------------------------------------------

## Generate a random U32 in the range `[0, range)` returning the new state of the backing PCG
## See [www.pcg-random.org/posts/bounded-rands.html](https://www.pcg-random.org/posts/bounded-rands.html)
## Adapted from "Lemire's Method", post by M.E. O'Neill
## If a true random generator was backing this, technically there's a very very slim chance of this
## while loop never terminating, but because the backing PCG in this implimentation is well
## distributed in its values over time, it will quickly find a value that doesn't suffer from a bias
## toward lower numbers in the range. The pathological case is when `range` is slightly larger than `2**31`
## causing almost half of generated candidates to be rejected. In practice, with small `range` values,
## there is an extremely miniscule chance of generating even a single value that needs to be rejected.
##
u32_exclusive_range_unbiased : State, U32 -> { value : U32, state : State }
u32_exclusive_range_unbiased = |state, range| {
	# `t` represents the exact number of outputs from the backing
	# PCG that we must reject in order to remain unbiased for this
	# particular range
	t = (U64.pow(2, 32) % range.to_u64()).to_u32_wrap()

	var $state = state
	while True {
		x = permute($state)
		$state = update($state)
		m = x.to_u64() * range.to_u64()
		l = m.to_u32_wrap()
		if l >= t {
			value = m.shift_right_by(32).to_u32_wrap()
			return { value, state: $state }
		}
	}

}

sort = |x, y|
	if x < y {
		(x, y)
	} else {
		(y, x)
	}

# See `RXS M XS` constants (line 168?)
# and `_DEFAULT_` constants (line 276?)
# in the PCG C++ header (see link above).
default_u32_permute_multiplier = 277_803_737

default_u32_permute_random_xor_shift = 28

default_u32_permute_random_xor_shift_increment = 4

default_u32_permute_xor_shift = 22

default_u32_update_increment = 2_891_336_453

default_u32_update_multiplier = 747_796_405

# See `pcg_output_rxs_m_xs_8_8` (on line 170?) in the PCG C++ header (see link above).
permute : Random.State -> U32
permute = |Random.State.({ s, c })|
	pcg_rxs_m_xs(s, c.permute_random_xor_shift, c.permute_random_xor_shift_increment, c.permute_multiplier, c.permute_xor_shift)

# See section 6.3.4 on page 45 in the PCG paper (see link above).
pcg_rxs_m_xs : U32, U32, U32, U32, U32 -> U32
pcg_rxs_m_xs = |state, random_xor_shift, random_xor_shift_increment, multiplier, xor_shift| {
	inner_shifted = shift_right_zf_by_u32(random_xor_shift, state)
	inner_shift = add_wrap_u32(inner_shifted, random_xor_shift_increment)
	inner = shift_right_zf_by_u32(inner_shift, state)

	partial = mul_wrap_u32(U32.bitwise_xor(state, inner), multiplier)

	U32.bitwise_xor(partial, shift_right_zf_by_u32(xor_shift, partial))
}

shift_right_zf_by_u32 : U32, U32 -> U32
shift_right_zf_by_u32 = |value, shift|
	U32.shift_right_zf_by(value, (shift % 32).to_u8_wrap())

add_wrap_u32 : U32, U32 -> U32
add_wrap_u32 = |a, b| (a.to_u64() + b.to_u64()).to_u32_wrap()

add_wrap_i32 : I32, I32 -> I32
add_wrap_i32 = |a, b| (a.to_i64() + b.to_i64()).to_i32_wrap()

mul_wrap_u32 : U32, U32 -> U32
mul_wrap_u32 = |a, b| (a.to_u64() * b.to_u64()).to_u32_wrap()

# See section 4.1 on page 20 in the PCG paper (see link above).
pcg_step : U32, U32, U32 -> U32
pcg_step = |state, multiplier, increment| add_wrap_u32(mul_wrap_u32(state, multiplier), increment)

# See `pcg_oneseq_8_step_r` (line 409?) in the PCG C++ header (see link above).
update : Random.State -> Random.State
update = |Random.State.({ s, c })| {
	s_new : U32
	s_new = pcg_step(s, c.update_multiplier, c.update_increment)

	Random.State.({ s: s_new, c })
}

expect {
	always_five = Random.static(5)

	Iter.fold(
		0..<100,
		True,
		|all_passed, seed_num| {
			generation = Random.step(Random.seed(seed_num), always_five)
			value = generation.value

			all_passed and value == 5
		},
	)
}

expect {
	doubled_int = Random.map(Random.bounded_i32(-100, 100), |i| i * 2)

	Iter.fold(
		0..<100,
		True,
		|all_passed, seed_num| {
			next_seed = Random.seed(seed_num)
			rand_generation = Random.step(next_seed, Random.bounded_i32(-100, 100))
			doubled_rand_generation = Random.step(next_seed, doubled_int)
			rand_int = rand_generation.value
			doubled_rand_int = doubled_rand_generation.value

			all_passed and rand_int * 2 == doubled_rand_int
		},
	)
}

expect {
	color_component_gen = Random.bounded_i32(0, 255)
	rgb_generator = { r: color_component_gen, g: color_component_gen, b: color_component_gen }.Random

	test_seed = Random.seed(123)
	actual = rgb_generator(test_seed)
	expected : { r : I32, g : I32, b : I32 }
	expected = { r: 244, g: 173, b: 75 }

	actual.value == expected
}

expect {
	test_generator = Random.u8
	test_seed = Random.seed(123)
	actual = test_generator(test_seed)
	expected : U8
	expected = 65
	actual.value == expected
}

expect {
	test_generator = Random.bounded_u16(0, 250)
	test_seed = Random.seed(123)
	actual = test_generator(test_seed)
	expected : U16
	expected = 239
	actual.value == expected
}

expect {
	test_generator = Random.bounded_u32(0, 250)
	test_seed = Random.seed(123)
	actual = test_generator(test_seed)
	expected : U32
	expected = 239
	actual.value == expected
}

expect {
	test_generator = Random.bounded_i8(0, 9)
	test_seed = Random.seed(6)
	actual = test_generator(test_seed)
	expected : I8
	expected = 3
	actual.value == expected
}

expect {
	test_generator = Random.bounded_i16(0, 9)
	test_seed = Random.seed(6)
	actual = test_generator(test_seed)
	expected : I16
	expected = 3
	actual.value == expected
}

expect {
	test_generator = Random.bounded_i32(10, 9)
	test_seed = Random.seed(6)
	actual = test_generator(test_seed)
	expected : I32
	expected = 9
	actual.value == expected
}

expect {
	u32_generator = Random.bounded_u32(42, 42)
	i32_generator = Random.bounded_i32(-7, -7)

	Iter.fold(
		0..<100,
		True,
		|all_passed, seed_num| {
			u32_actual = Random.step(Random.seed(seed_num), u32_generator).value
			i32_actual = Random.step(Random.seed(seed_num), i32_generator).value

			all_passed and u32_actual == 42 and i32_actual == -7
		},
	)
}

expect {
	normal_order = Random.bounded_u32(25, 75)
	reversed_order = Random.bounded_u32(75, 25)

	Iter.fold(
		0..<100,
		True,
		|all_passed, seed_num| {
			state = Random.seed(seed_num)
			normal = Random.step(state, normal_order)
			reversed = Random.step(state, reversed_order)

			all_passed and normal.value == reversed.value and normal.state == reversed.state
		},
	)
}

expect {
	unsigned = Random.bounded_u32(25, 75)
	signed = Random.bounded_i32(-10, 10)

	Iter.fold(
		0..<1_000,
		True,
		|all_passed, seed_num| {
			u = Random.step(Random.seed(seed_num), unsigned).value
			i = Random.step(Random.seed(seed_num), signed).value

			all_passed and u >= 25 and u <= 75 and i >= -10 and i <= 10
		},
	)
}

expect {
	range : U32
	range = 2_147_483_649
	initial_state = Random.seed(0)

	threshold = (U64.pow(2, 32) % range.to_u64()).to_u32_wrap()
	first_candidate = permute(initial_state)
	first_low_bits = (first_candidate.to_u64() * range.to_u64()).to_u32_wrap()
	state_after_first_rejection = update(initial_state)
	second_candidate = permute(state_after_first_rejection)
	second_low_bits = (second_candidate.to_u64() * range.to_u64()).to_u32_wrap()
	state_after_second_rejection = update(state_after_first_rejection)
	third_candidate = permute(state_after_second_rejection)
	third_low_bits = (third_candidate.to_u64() * range.to_u64()).to_u32_wrap()
	state_after_third_rejection = update(state_after_second_rejection)
	accepted_candidate = permute(state_after_third_rejection)
	accepted_product = accepted_candidate.to_u64() * range.to_u64()
	accepted_low_bits = accepted_product.to_u32_wrap()
	expected_value = accepted_product.shift_right_by(32).to_u32_wrap()
	expected_state = update(state_after_third_rejection)

	actual = u32_exclusive_range_unbiased(initial_state, range)

	first_low_bits < threshold and second_low_bits < threshold and third_low_bits < threshold and accepted_low_bits >= threshold and actual.value == expected_value and actual.state == expected_state
}

# Test large ranges to avoid overflow when calculating difference between min and max

expect {
	test_generator = Random.bounded_i32(I32.lowest, I32.highest - 1)
	test_seed = Random.seed(6)
	actual = test_generator(test_seed)
	expected : I32
	expected = -480661227
	actual.value == expected
}

expect {
	test_generator = Random.bounded_i32(I32.highest, I32.lowest)
	test_seed = Random.seed(6)
	actual = test_generator(test_seed)
	expected : I32
	expected = 1666822422
	actual.value == expected
}

expect {
	test_generator = Random.bounded_u32(U32.lowest, U32.highest - 1)
	test_seed = Random.seed(6)
	actual = test_generator(test_seed)
	expected : U32
	expected = 1666822421
	actual.value == expected
}

expect {
	test_generator = Random.bounded_u32(U32.highest, U32.lowest)
	test_seed = Random.seed(6)
	actual = test_generator(test_seed)
	expected : U32
	expected = 1666822422
	actual.value == expected
}
