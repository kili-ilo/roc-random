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
	u8 : Generator(U8)
	u8 = bounded_u8(U8.lowest, U8.highest)

	## Construct a `Generator` for 8-bit unsigned integers between two boundaries (inclusive)
	bounded_u8 : U8, U8 -> Generator(U8)
	bounded_u8 = |x, y| between_u8(x, y)

	## Construct a `Generator` for 8-bit signed integers
	i8 : Generator(I8)
	i8 = {
		(minimum, maximum) = (I8.lowest, I8.highest)
		# TODO: Remove these `I64` dependencies.
		range = maximum.to_i64() - minimum.to_i64() + 1
		|state| {
			# TODO: Analyze this. The mod-ing might be biased towards a smaller offset!
			offset = I64.rem_by(map_to_i32(permute(state)).to_i64() - I8.lowest.to_i64(), range)
			value = (minimum.to_i64() + offset).to_i8_wrap()
			{ value, state: update(state) }
		}
	}

	## Construct a `Generator` for 8-bit signed integers between two boundaries (inclusive)
	bounded_i8 : I8, I8 -> Generator(I8)
	bounded_i8 = |x, y| {
		(minimum, maximum) = sort(x, y)
		# TODO: Remove these `I64` dependencies.
		range = maximum.to_i64() - minimum.to_i64() + 1
		|state| {
			# TODO: Analyze this. The mod-ing might be biased towards a smaller offset!
			offset = I64.rem_by(map_to_i32(permute(state)).to_i64() - I8.lowest.to_i64(), range)
			value = (minimum.to_i64() + offset).to_i8_wrap()
			{ value, state: update(state) }
		}
	}

	## Construct a `Generator` for 16-bit unsigned integers
	u16 : Generator(U16)
	u16 = bounded_u16(U16.lowest, U16.highest)

	## Construct a `Generator` for 16-bit unsigned integers between two boundaries (inclusive)
	bounded_u16 : U16, U16 -> Generator(U16)
	bounded_u16 = |x, y| between_u16(x, y)

	## Construct a `Generator` for 16-bit signed integers
	i16 : Generator(I16)
	i16 = {
		(minimum, maximum) = (I16.lowest, I16.highest)
		# TODO: Remove these `I64` dependencies.
		range = maximum.to_i64() - minimum.to_i64() + 1
		|state| {
			# TODO: Analyze this. The mod-ing might be biased towards a smaller offset!
			offset = I64.rem_by(map_to_i32(permute(state)).to_i64() - I16.lowest.to_i64(), range)
			value = (minimum.to_i64() + offset).to_i16_wrap()
			{ value, state: update(state) }
		}
	}

	## Construct a `Generator` for 16-bit signed integers between two boundaries (inclusive)
	bounded_i16 : I16, I16 -> Generator(I16)
	bounded_i16 = |x, y| {
		(minimum, maximum) = sort(x, y)
		# TODO: Remove these `I64` dependencies.
		range = maximum.to_i64() - minimum.to_i64() + 1
		|state| {
			# TODO: Analyze this. The mod-ing might be biased towards a smaller offset!
			offset = I64.rem_by(map_to_i32(permute(state)).to_i64() - I16.lowest.to_i64(), range)
			value = (minimum.to_i64() + offset).to_i16_wrap()
			{ value, state: update(state) }
		}
	}

	## Construct a `Generator` for 32-bit unsigned integers
	u32 : Generator(U32)
	u32 = between_u32(U32.lowest, U32.highest)

	## Construct a `Generator` for 32-bit unsigned integers between two boundaries (inclusive)
	bounded_u32 : U32, U32 -> Generator(U32)
	bounded_u32 = |x, y| between_u32(x, y)

	## Construct a `Generator` for 32-bit signed integers
	i32 : Generator(I32)
	i32 = {
		(minimum, maximum) = (I32.lowest, I32.highest)
		# TODO: Remove these `I64` dependencies.
		range = maximum.to_i64() - minimum.to_i64() + 1
		|state| {
			# TODO: Analyze this. The mod-ing might be biased towards a smaller offset!
			offset = I64.rem_by(map_to_i32(permute(state)).to_i64() - I32.lowest.to_i64(), range)
			value = (minimum.to_i64() + offset).to_i32_wrap()
			{ value, state: update(state) }
		}
	}

	## Construct a `Generator` for 32-bit signed integers between two boundaries (inclusive)
	bounded_i32 : I32, I32 -> Generator(I32)
	bounded_i32 = |x, y| {
		(minimum, maximum) = sort(x, y)
		# TODO: Remove these `I64` dependencies.
		range = maximum.to_i64() - minimum.to_i64() + 1
		|state| {
			# TODO: Analyze this. The mod-ing might be biased towards a smaller offset!
			offset = I64.rem_by(map_to_i32(permute(state)).to_i64() - I32.lowest.to_i64(), range)
			value = (minimum.to_i64() + offset).to_i32_wrap()
			{ value, state: update(state) }
		}
	}
}

# Helpers for the above constructors -------------------------------------------
between_u8 : U8, U8 -> Random.Generator(U8)
between_u8 = |x, y| {
	(minimum, maximum) = sort(x, y)
	min16 = minimum.to_u16()
	range = maximum.to_u16() - min16 + 1

	|s| {
		# TODO: Analyze this. The mod-ing might be biased towards a smaller offset!
		offset = permute(s).to_u8_wrap().to_u16() % range
		value = (min16 + offset).to_u8_wrap()
		state = update(s)

		{ value, state }
	}
}

between_u16 : U16, U16 -> Random.Generator(U16)
between_u16 = |x, y| {
	(minimum, maximum) = sort(x, y)
	min32 = minimum.to_u32()
	range = maximum.to_u32() - min32 + 1

	|s| {
		# TODO: Analyze this. The mod-ing might be biased towards a smaller offset!
		offset = permute(s).to_u16_wrap().to_u32() % range
		value = (min32 + offset).to_u16_wrap()
		state = update(s)

		{ value, state }
	}
}

between_u32 : U32, U32 -> Random.Generator(U32)
between_u32 = |x, y| {
	(minimum, maximum) = sort(x, y)
	min64 = minimum.to_u64()
	range = maximum.to_u64() - min64 + 1

	|s| {
		# TODO: Analyze this. The mod-ing might be biased towards a smaller offset!
		offset = permute(s).to_u64() % range
		value = (min64 + offset).to_u32_wrap()
		state = update(s)

		{ value, state }
	}
}

map_to_i32 : U32 -> I32
map_to_i32 = |x| {
	middle = I32.highest.to_u32_wrap()
	if x <= middle {
		I32.lowest + x.to_i32_wrap()
	} else {
		(x - middle - 1).to_i32_wrap()
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

	next_seed = Random.seed(123)
	rand_generation = Random.step(next_seed, rgb_generator)
	rand_rgb = rand_generation.value

	rand_rgb == { r: 65, g: 156, b: 137 }
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
	expected = 182
	actual.value == expected
}

expect {
	test_generator = Random.bounded_u32(0, 250)
	test_seed = Random.seed(123)
	actual = test_generator(test_seed)
	expected : U32
	expected = 143
	actual.value == expected
}

expect {
	test_generator = Random.bounded_i8(0, 9)
	test_seed = Random.seed(6)
	actual = test_generator(test_seed)
	expected : I8
	expected = -8
	actual.value == expected
}

expect {
	test_generator = Random.bounded_i16(0, 9)
	test_seed = Random.seed(6)
	actual = test_generator(test_seed)
	expected : I16
	expected = -8
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
