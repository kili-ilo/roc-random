## PCG algorithms, constants, and wrappers
##
## For more information about PCG see [www.pcg-random.org](https://www.pcg-random.org)
##
## PCG is a family of simple fast space-efficient statistically good algorithms for random number generation.
##

Random := [].{

	# This implementation is based on this paper [PCG: A Family of Simple Fast Space-Efficient Statistically Good Algorithms for Random Number Generation](https://www.pcg-random.org/pdf/hmc-cs-2014-0905.pdf)
	# and this C++ header: [pcg_variants.h](https://github.com/imneme/pcg-c/blob/master/include/pcg_variants.h).
	#
	# Original Roc implementation by [JanCVanB](https://github.com/JanCVanB), January 2022
	#
	# Abbreviations:
	# - PCG = Permuted Congruential Generator
	# - RXS = Random XorShift (see section 5.5.1 on page 36 in the paper)
	# - M = Multiplication (see section 6.3.4 on page 45 in the paper)
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
	State :: { s : U32, update_increment : U32 }.{
		is_eq : _

		## Manually step the random state forward by n steps. The sequence has a
		## period of 2 to the 32 steps, and will wrap around to the beginning
		## after that.
		fast_forward : State, U32 -> State
		fast_forward = |state, var $delta| {
			var $acc_mult = 1.U32
			var $acc_plus = 0.U32
			var $cur_mult = default_u32_update_multiplier
			var $cur_plus = state.update_increment

			while $delta > 0 {
				if $delta % 2 == 1 {
					$acc_mult = mul_wrap_u32($acc_mult, $cur_mult)
					$acc_plus =
						mul_wrap_u32($acc_plus, $cur_mult)
							|> add_wrap_u32($cur_plus)
				}
				$cur_plus =
					add_wrap_u32($cur_mult, 1)
						|> mul_wrap_u32($cur_plus)
				$cur_mult = mul_wrap_u32($cur_mult, $cur_mult)
				$delta = $delta // 2
			}

			next_s =
				mul_wrap_u32(state.s, $acc_mult)
					|> add_wrap_u32($acc_plus)

			{ ..state, s: next_s }
		}

		## Manually step the random state backward by n steps. Will wrap around to
		## the end of the sequence when stepping backward from the "0th" state.
		rewind : State, U32 -> State
		rewind = |state, delta| state.fast_forward(negate_wrap_u32(delta))
	}

	## Construct an initial "seed" `State` for `Generator`s
	seed : U32 -> State
	seed = |initial_seed| {
		default_sequence_id = U32.shr_zf_wrap(default_u32_update_increment, 1)
		seed_variant(initial_seed, default_sequence_id)
	}

	## Construct a specific "variant" of a "seed" `State` for more advanced use.
	##
	## Takes a starting seed and a sequence ID (which corresponds to its
	## internal `update_increment`). Any `State`s with different sequence ID's will
	## share no consecutive number pairs with each other, even if they are
	## initialized with the same seed.
	##
	## Any value given for the sequence ID between 0 and 2**31 will be unique.
	## Above that, the sequence ID wraps around to the bottom, so there are about
	## two billion unique choices for sequence ID
	seed_variant : U32, U32 -> State
	seed_variant = |initial_seed, sequence_id| {
		# ensure `update_increment` is odd, shifting `sequence_id` and discarding
		# its most significant bit in the process
		update_increment = sequence_id.shl_wrap(1).bitwise_or(1)

		var $seed = State.({ s: 0, update_increment })
		$seed = $seed |> update
		$seed = { ..$seed, s: $seed.s + initial_seed }
		$seed |> update
	}

	## Generate a `Generation` from a state
	step : State, Generator(value) -> Generation(value)
	step = |state, generate_func| generate_func(state)

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

	## Create a `Generator` by chaining one `Generator` with a function that
	## returns a new `Generator`
	##
	## ```roc
	## generate_random_amount_of_random_u8s =
	##     Random.chain(Random.bounded_U64(1, 10), |count| Random.list(Random.u8, count))
	## ```
	chain : Generator(a), (a -> Generator(b)) -> Generator(b)
	chain = |first_generator, func| {
		|state| {
			{ value, state: next_state } = first_generator(state)
			func(value)(next_state)
		}
	}

	## Generate a list of random values.
	## ```
	## generate_10_random_u8s : Generator(List(U8))
	## generate_10_random_u8s =
	##     Random.list(Random.u8, 10)
	## ```
	list : Generator(a), U64 -> Generator(List(a))
	list = |generator, length| {
		|var $state| {
			var $result = List.with_capacity(length)

			for _ in 0..<length {
				{ value: item, state: $state } = generator($state)
				$result = $result.append(item)
			}

			{ value: $result, state: $state }
		}
	}

	## Given a `List` generate a shuffled version of that `List`
	shuffle : List(a) -> Generator(List(a))
	shuffle = |items| {
		# TODO: does this create a longstanding reference to the unshuffled
		# items potentially preventing mutation optimization at the
		# `shuffle` usage site?
		|var $state| {
			if items.len() < 2 return { value: items, state: $state }

			var $items = items
			for i in List.from_iter((1..<items.len()).iter()).rev() {
				{ value: choice_i, state: $state } =
					bounded_u64(0, i)($state)
				$items = match $items.swap(i, choice_i) {
					Ok(l) => l
					Err(_) => {
						crash "error in `Random.shuffle`"
						[]
					}
				}
			}

			{ value: $items, state: $state }
		}
	}

	## A `Generator` that generates `Bool.True` or `Bool.False` with equal probabilty
	bool : Generator(Bool)
	bool = u32 |> map(U32.is_odd)

	## A `Generator` for the full range of 8-bit unsigned integers
	u8 : Generator(U8)
	# NOTE: We are just taking the bottom 8 bits of the generated `U32` value
	# Some backing generators have worse statistical properties in the low-order bits
	# and it would be wise to use the upper 8 bits instead, but according to the pcg
	# paper (M.E. O'Neill) this backing generator has good statistical quality throughout
	# all the bits (perhaps from the good high bits being rotated/shifted around etc)
	u8 = u32 |> map(U32.to_u8_wrap)

	## Construct a `Generator` for 8-bit unsigned integers between two boundaries (inclusive)
	bounded_u8 : U8, U8 -> Generator(U8)
	bounded_u8 = |x, y| bounded_u32_helper(x, y) |> map(U32.to_u8_wrap)

	## A `Generator` for the full range of 8-bit signed integers
	i8 : Generator(I8)
	i8 = u32 |> map(U32.to_i8_wrap)

	## Construct a `Generator` for 8-bit signed integers between two boundaries (inclusive)
	bounded_i8 : I8, I8 -> Generator(I8)
	bounded_i8 = |x, y| bounded_i32_helper(x, y) |> map(I32.to_i8_wrap)

	## A `Generator` for the full range of 16-bit unsigned integers
	u16 : Generator(U16)
	u16 = u32 |> map(U32.to_u16_wrap)

	## Construct a `Generator` for 16-bit unsigned integers between two boundaries (inclusive)
	bounded_u16 : U16, U16 -> Generator(U16)
	bounded_u16 = |x, y| bounded_u32_helper(x, y) |> map(U32.to_u16_wrap)

	## A `Generator` for the full range of 16-bit signed integers
	i16 : Generator(I16)
	i16 = u32 |> map(U32.to_i16_wrap)

	## Construct a `Generator` for 16-bit signed integers between two boundaries (inclusive)
	bounded_i16 : I16, I16 -> Generator(I16)
	bounded_i16 = |x, y| bounded_i32_helper(x, y) |> map(I32.to_i16_wrap)

	## A `Generator` for the full range of 32-bit unsigned integers
	u32 : Generator(U32)
	u32 = |state| {
		value = state |> permute
		next_state = state |> update

		{ value, state: next_state }
	}

	## Construct a `Generator` for 32-bit unsigned integers between two boundaries (inclusive)
	bounded_u32 : U32, U32 -> Generator(U32)
	bounded_u32 = |x, y| bounded_u32_helper(x, y)

	## A `Generator` for the full range of 32-bit signed integers
	i32 : Generator(I32)
	i32 = u32 |> map(U32.to_i32_wrap)

	## Construct a `Generator` for 32-bit signed integers between two boundaries (inclusive)
	bounded_i32 : I32, I32 -> Generator(I32)
	bounded_i32 = |x, y| bounded_i32_helper(x, y)

	## A `Generator` for the full range of 64-bit unsigned integers
	u64 : Generator(U64)
	u64 = {
		component_generator : Generator({ hi : U32, lo : U32 })
		component_generator = {
			hi: u32,
			lo: u32,
		}.Random

		component_generator
			|> map(
				|{ hi, lo }| {
					hi_shifted = hi.to_u64().shl_wrap(32)
					hi_shifted.bitwise_or(lo.to_u64())
				},
			)
	}

	## Construct a `Generator` for 64-bit unsigned integers between two boundaries (inclusive)
	bounded_u64 : U64, U64 -> Generator(U64)
	bounded_u64 = |x, y| {
		(minimum, maximum) = sort(x, y)

		range = match (maximum - minimum).plus_try(1) {
			# we need full range `U64` generator
			Err(Overflow) => return Random.u64
			Ok(r) => r
		}

		|var $state| {
			{ value: offset, state: $state } =
				u64_exclusive_range_unbiased(range)($state)
			{ value: minimum + offset, state: $state }
		}
	}

	## A `Generator` for the full range of 64-bit signed integers
	i64 : Generator(I64)
	i64 = u64 |> map(U64.to_i64_wrap)

	## Construct a `Generator` for 64-bit signed integers between two boundaries (inclusive)
	bounded_i64 : I64, I64 -> Generator(I64)
	bounded_i64 = |x, y| {
		(minimum, maximum) = sort(x, y)

		range = match I64.abs_diff(maximum, minimum).plus_try(1) {
			# we need full range `U64` generator
			Err(Overflow) => return Random.i64
			Ok(r) => r
		}

		|var $state| {
			{ value: offset, state: $state } =
				u64_exclusive_range_unbiased(range)($state)

			offset_i64 = offset.to_i64_wrap()

			value = add_wrap_i64(minimum, offset_i64)

			{ value, state: $state }
		}
	}

	## `Generator` for an `F32` between two values excluding the high one
	## It is generally recommended NOT to use this when your intention is to convert
	## the floating point number to an integer due to potential rounding errors
	## etc, prefer the `bounded_*` integer generators for those cases
	f32 : F32, F32 -> Generator(F32)
	f32 = |lo, hi| {
		# This generator is aimed at a balance between performance/simplicity and
		# statistical correctness. It will always produce a value less than the high
		# bound (important if someone is converting this to an array index)
		#
		# we start with an equally distributed `F32` in [1.0 .. 2.0) then
		# scale and offset it to the desired output range
		#
		# Keep in sync with `Random.f64`

		width = hi - lo

		input_is_valid = lo.is_finite()
			and hi.is_finite()
				and width.is_finite()
					and width.is_positive()

		expect input_is_valid

		Random.u32
			|> map(
				|rand| {
					if !input_is_valid return lo

					# these bits hold just the exponent for the range [1.0 .. 2.0)
					exponent_bits = F32.to_bits(1.0)

					# random mantissa of 1.xxxxxx from lowest 23 bits of rand
					mantissa_bits = U32.bitwise_and(rand, 0x007f_ffff)

					float_bits = U32.bitwise_or(exponent_bits, mantissa_bits)

					float_1_to_2 = F32.from_bits(float_bits)

					# bring that float down to [0.0 .. 1.0)
					ratio = float_1_to_2 - 1.0

					result = lo + (width * ratio)

					# in pathological rounding cases `result` can be too high
					# if this happens, step down to the nearest valid value below `hi`
					if result >= hi {
						step_down_f32(hi)
					} else {
						result
					}
				},
			)
	}

	## `Generator` for an `F64` between two values excluding the high one
	## It is generally recommended NOT to use this when your intention is to convert
	## the floating point number to an integer due to potential rounding errors
	## etc, prefer the `bounded_*` integer generators for those cases
	f64 : F64, F64 -> Generator(F64)
	f64 = |lo, hi| {
		# see commentary on `Random.f32` (these must be kept in sync!)

		width = hi - lo

		input_is_valid = lo.is_finite()
			and hi.is_finite()
				and width.is_finite()
					and width.is_positive()

		expect input_is_valid

		Random.u64
			|> map(
				|rand| {
					if !input_is_valid return lo

					# these bits hold just the exponent for the range [1.0 .. 2.0)
					exponent_bits = F64.to_bits(1.0)

					# random mantissa of 1.xxxxxx from lowest 52 bits of rand
					mantissa_bits = U64.bitwise_and(rand, 0x000f_ffff_ffff_ffff)

					float_bits = U64.bitwise_or(exponent_bits, mantissa_bits)

					float_1_to_2 = F64.from_bits(float_bits)

					# bring that float down to [0.0 .. 1.0)
					ratio = float_1_to_2 - 1.0

					result = lo + (width * ratio)

					# in pathological rounding cases `result` can be too high
					# if this happens, step down to the nearest valid value below `hi`
					if result >= hi {
						step_down_f64(hi)
					} else {
						result
					}
				},
			)
	}

	## Creates a `Generator` that randomly chooses from a series of items.
	## The first item is given explicitly as the first argument to ensure that
	## there's always at least one item to choose from. See `Random.choice_try`
	## for an alternative that checks for an empty `List`.
	choice : a, List(a) -> Generator(a)
	choice = |first, rest| {
		num_choices = 1 + rest.len()

		# subtract 1 because bounded_u64 uses an inclusive range
		choice_index_generator = Random.bounded_u64(0, num_choices - 1)

		choice_index_generator
			|> map(
				|choice_index| {
					if choice_index == 0 {
						first
					} else {
						rest_index = choice_index - 1
						match rest.get(rest_index) {
							Ok(item) => item
							Err(OutOfBounds) => {
								crash "Random.choice: index out of bounds"
							}
						}
					}
				},
			)
	}

	## Creates a `Generator` that randomly chooses an item from a `List`.
	## Returns `Err(ListWasEmpty)` upon construction if given an empty `List`.
	## See `Random.choice` for a version that cannot return an error.
	choice_try : List(a) -> Try(Generator(a), [ListWasEmpty])
	choice_try = |items| {
		match items {
			[] => Err(ListWasEmpty)
			[first, .. as rest] => Ok(choice(first, rest))
		}
	}

	## Creates a `Generator` that randomly chooses from a series of items with
	## an associated weight. Higher weight indicates a higher probability
	## of selection. The weights don't need to add up to any particular value,
	## probability is relative to the total sum of given weights.
	## The first item is given explicitly as the first argument to ensure that
	## there's always at least one item to choose from.
	## See `Random.choice_weighted_try` for an alternative that checks for an
	## empty `List`
	choice_weighted : (a, F64), List((a, F64)) -> Generator(a)
	choice_weighted = |first, rest| {
		validate_weight = |weight| {
			expect weight.is_finite() and weight >= 0.0
			if (weight.is_finite()) weight.abs() else 0.0
		}

		# TODO: using noisy concat version due to current compiler bug
		all_choices_iter =
			(Iter.single(first).concat(rest.iter()))
				.map(|(item, weight)| (item, validate_weight(weight)))

		total_weight = all_choices_iter.map(|(_, weight)| weight).sum()

		Random.f64(0.0, total_weight)
			|> map(
				|rand| {
					var $cumulative_sum = 0.0

					for (item, weight) in all_choices_iter {
						$cumulative_sum = $cumulative_sum + weight
						if rand < $cumulative_sum return item
					}

					# we can only get here due to rounding error, just return last item
					last_choice = rest.last().ok_or(first)
					last_choice.0
				},
			)
	}

	## Creates a `Generator` that randomly chooses from a series of items with
	## an associated weight. Higher weight indicates higher a higher probability
	## of selection. The weights don't need to add up to any particular value,
	## probability is relative to the total sum of given weights.
	## Returns `Err(ListWasEmpty)` upon construction if given an empty `List`.
	## See `Random.choice_weighted` for a version that cannot return an error.
	choice_weighted_try : List((a, F64)) -> Try(Generator(a), [ListWasEmpty])
	choice_weighted_try = |items| {
		match items {
			[] => Err(ListWasEmpty)
			[first, .. as rest] => Ok(choice_weighted(first, rest))
		}
	}
}

# Helpers for the above constructors -------------------------------------------

# Generate a random U32 in the range `[0, range)` returning the new state of
# the backing PCG See [www.pcg-random.org/posts/bounded-rands.html](https://www.pcg-random.org/posts/bounded-rands.html)
# Ported from PCG-C implementation. If a truly random generator was backing
# this, technically there would be a very very slim chance of this while loop
# never terminating, but because the backing PCG in this implementation is well
# distributed in its values over time, it will quickly find a value that
# doesn't suffer from a bias toward lower numbers in the range.
# The pathological value for `range` is slightly larger than `2**31` causing
# almost half of generated candidates to be rejected. In practice, with small
# `range` values, there is an extremely miniscule chance of generating even a
# single value that needs to be rejected.
u32_exclusive_range_unbiased : U32 -> Generator(U32)
u32_exclusive_range_unbiased = |range| {
	|var $state| {
		threshold = negate_wrap_u32(range) % range

		while True {
			{ value: x, state: $state } = Random.u32($state)
			if x >= threshold {
				return { value: x % range, state: $state }
			}
		}
	}
}

# see `u32_exclusive_range_unbiased` for commentary
u64_exclusive_range_unbiased : U64 -> Generator(U64)
u64_exclusive_range_unbiased = |range| {
	|var $state| {
		threshold = negate_wrap_u64(range) % range

		while True {
			{ value: x, state: $state } = Random.u64($state)
			if x >= threshold {
				return { value: x % range, state: $state }
			}
		}
	}
}

# convenience function that takes inclusive ranges of `U32`s or smaller ints
# (with lower bound offset) and dispatches to unbiased exclusive range
# generator
bounded_u32_helper : int, int -> Generator(U32) where [int.to_u32 : int -> U32]
bounded_u32_helper = |x, y| {
	(minimum, maximum) = sort(x.to_u32(), y.to_u32())

	range : U32
	range = match (maximum - minimum).plus_try(1) {
		Ok(r) => r
		# If absolute range doesn't fit in a U32 we need the full range generator
		Err(Overflow) => return Random.u32
	}

	|var $state| {
		{ value: offset, state: $state } = u32_exclusive_range_unbiased(range)($state)

		value = minimum + offset

		{ value, state: $state }
	}
}

# similar to `bounded_u32_helper` but handles signed arithmetic for result
bounded_i32_helper : int, int -> Generator(I32) where [int.to_i32 : int -> I32]
bounded_i32_helper = |x, y| {
	(minimum, maximum) = sort(x.to_i32(), y.to_i32())
	range : U32
	range = match I32.abs_diff(maximum, minimum).plus_try(1) {
		Ok(r) => r
		# If absolute range doesn't fit in a U32 we need the full range generator
		Err(Overflow) => return Random.i32
	}

	|var $state| {
		{ value: offset, state: $state } = u32_exclusive_range_unbiased(range)($state)

		offset_i32 = offset.to_i32_wrap()

		value = add_wrap_i32(minimum, offset_i32)

		{ value, state: $state }
	}
}

sort = |x, y|
	if x <= y {
		(x, y)
	} else {
		(y, x)
	}

# See `RXS M XS` and `PCG_DEFINE_CONSTANT(...)`
# in the PCG C++ header (see link above).
default_u32_permute_multiplier = 277_803_737

default_u32_update_increment = 2_891_336_453

default_u32_update_multiplier = 747_796_405

# Take the current state and permute it with the RXS M XS algorithm,
# returning the permuted state as a random U32, leaving the internal
# state unchanged
permute : Random.State -> U32
permute = |state|
	pcg_rxs_m_xs(state.s)

# See section 6.3.4 on page 45 in the PCG paper (see link above).
# Also see `pcg_output_rxs_m_xs_32_32` in the PCG C implementation or the
# templated function `rxs_m_xs_mixin.output` in the PCG C++ header. The C++ version
# is heavily templated to work on different variations of the rxs_m_xs algorithm,
# but the variable names are more descriptive than the C version.
pcg_rxs_m_xs : U32 -> U32
pcg_rxs_m_xs = |state| {
	output_bitcount = 32
	state_bitcount = 32
	rxs_op_bitcount = 4

	rxs_shift_op = {
		shift_amount = state_bitcount - rxs_op_bitcount

		state
			.shr_zf_wrap(shift_amount)
			.to_u8_wrap()
	}

	first_xor_shift_amount = rxs_shift_op + rxs_op_bitcount

	permute_multiplier = default_u32_permute_multiplier

	final_xor_shift_amount = ((2 * output_bitcount) + 2) // 3

	state
		|> xor_shift(first_xor_shift_amount)
		|> mul_wrap_u32(permute_multiplier)
		|> xor_shift(final_xor_shift_amount)
}

# See section 4.1 on page 20 in the PCG paper (see link above).
pcg_step : U32, U32, U32 -> U32
pcg_step = |state, multiplier, increment| add_wrap_u32(mul_wrap_u32(state, multiplier), increment)

# See `pcg_setseq_32_step_r` in the PCG C header (see link above).
update : Random.State -> Random.State
update = |state| {
	next_s = pcg_step(state.s, default_u32_update_multiplier, state.update_increment)

	{ ..state, s: next_s }
}

# Common math helpers

xor_shift : U32, U8 -> U32
xor_shift = |value, shift_amount| {
	shifted = value.shr_zf_wrap(shift_amount)
	value.bitwise_xor(shifted)
}

add_wrap_u32 : U32, U32 -> U32
add_wrap_u32 = |a, b| (a.to_u64() + b.to_u64()).to_u32_wrap()

add_wrap_i32 : I32, I32 -> I32
add_wrap_i32 = |a, b| (a.to_i64() + b.to_i64()).to_i32_wrap()

add_wrap_u64 : U64, U64 -> U64
add_wrap_u64 = |a, b| (a.to_u128() + b.to_u128()).to_u64_wrap()

add_wrap_i64 : I64, I64 -> I64
add_wrap_i64 = |a, b| (a.to_i128() + b.to_i128()).to_i64_wrap()

mul_wrap_u32 : U32, U32 -> U32
mul_wrap_u32 = |a, b| (a.to_u64() * b.to_u64()).to_u32_wrap()

negate_wrap_u32 : U32 -> U32
negate_wrap_u32 = |a| a.bitwise_not() |> add_wrap_u32(1)

negate_wrap_u64 : U64 -> U64
negate_wrap_u64 = |a| a.bitwise_not() |> add_wrap_u64(1)

step_down_f32 : F32 -> F32
step_down_f32 = |a| {
	if a.is_nan() or a == -(F32.infinity) {
		return a
	}

	bits = if a.is_zero() {
		# for positive zero or negative zero, return highest negative subnormal
		0x8000_0000
	} else if a.is_positive() {
		# positive magnitude shrinks towards 0.0
		# also brings F32.infinity down to F32.highest
		F32.to_bits(a) - 1
	} else {
		# negative magnitude grows away from 0.0
		# also brings F32.lowest to negative F32.infinity
		F32.to_bits(a) + 1
	}

	F32.from_bits(bits)
}

step_down_f64 : F64 -> F64
step_down_f64 = |a| {
	if a.is_nan() or a == -(F64.infinity) {
		return a
	}

	bits = if a.is_zero() {
		# for positive zero or negative zero, return highest negative subnormal
		0x8000_0000_0000_0000
	} else if a.is_positive() {
		# positive magnitude shrinks towards 0.0
		# also brings F64.infinity down to F64.highest
		F64.to_bits(a) - 1
	} else {
		# negative magnitude grows away from 0.0
		# also brings F64.lowest to negative F64.infinity
		F64.to_bits(a) + 1
	}

	F64.from_bits(bits)
}

# Tests

test_passes_with_many_seeds : (U32 -> Bool) -> Bool
test_passes_with_many_seeds = |test_predicate| {
	var $all_passed = True

	for seed_num in 0..<100 {
		$all_passed = $all_passed and test_predicate(seed_num)
	}

	$all_passed
}

expect {
	always_five = Random.static(5)

	test_passes_with_many_seeds(
		|seed_num| {
			this_seed = Random.seed(seed_num)
			rand_generation = Random.step(this_seed, always_five)

			rand_generation.value == 5
		},
	)
}

expect {
	doubled_int = Random.bounded_i32(-100, 100) |> Random.map(|i| i * 2)

	test_passes_with_many_seeds(
		|seed_num| {
			this_seed = Random.seed(seed_num)
			rand_generation = Random.step(this_seed, Random.bounded_i32(-100, 100))
			doubled_rand_generation = Random.step(this_seed, doubled_int)
			rand_int = rand_generation.value
			doubled_rand_int = doubled_rand_generation.value

			rand_int * 2 == doubled_rand_int
		},
	)
}

expect {
	color_component_gen = Random.bounded_i32(0, 255)
	rgb_generator = { r: color_component_gen, g: color_component_gen, b: color_component_gen }.Random

	test_passes_with_many_seeds(
		|seed_num| {
			this_seed = Random.seed(seed_num)
			{ value: color, .. } = Random.step(this_seed, rgb_generator)
			{ r, g, b } = color

			r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255
		},
	)
}

# sanity check for non-bounded generators, checking for overflows/crashes etc
expect {
	unbounded_values = {
		bool: Random.bool,
		u8: Random.u8,
		i8: Random.i8,
		u16: Random.u16,
		i16: Random.i16,
		u32: Random.u32,
		i32: Random.i32,
		u64: Random.u64,
		i64: Random.i64,
	}.Random

	test_seed = Random.seed(123)

	_ = unbounded_values(test_seed)

	True
}

# bounds tests with random bounds

make_bounded_generator_test = |bound_generator, make_bounded_generator| {
	|seed_num| {
		var $state = Random.seed(seed_num)

		{ value: bound_a, state: $state } = Random.step($state, bound_generator)
		{ value: bound_b, state: $state } = Random.step($state, bound_generator)

		generator = make_bounded_generator(bound_a, bound_b)

		{ value, .. } = Random.step($state, generator)

		(lo, hi) = sort(bound_a, bound_b)

		value >= lo and value <= hi
	}
}

expect {
	test = make_bounded_generator_test(Random.u8, Random.bounded_u8)
	test_passes_with_many_seeds(test)
}

expect {
	test = make_bounded_generator_test(Random.u16, Random.bounded_u16)
	test_passes_with_many_seeds(test)
}

expect {
	test = make_bounded_generator_test(Random.u32, Random.bounded_u32)
	test_passes_with_many_seeds(test)
}

expect {
	test = make_bounded_generator_test(Random.u64, Random.bounded_u64)
	test_passes_with_many_seeds(test)
}

expect {
	test = make_bounded_generator_test(Random.i8, Random.bounded_i8)
	test_passes_with_many_seeds(test)
}

expect {
	test = make_bounded_generator_test(Random.i16, Random.bounded_i16)
	test_passes_with_many_seeds(test)
}

expect {
	test = make_bounded_generator_test(Random.i32, Random.bounded_i32)
	test_passes_with_many_seeds(test)
}

expect {
	test = make_bounded_generator_test(Random.i64, Random.bounded_i64)
	test_passes_with_many_seeds(test)
}

# bounds tests with single number range

expect {
	u32_generator = Random.bounded_u32(42, 42)

	test_passes_with_many_seeds(
		|seed_num| {
			actual = Random.step(Random.seed(seed_num), u32_generator).value
			actual == 42
		},
	)
}

expect {
	i32_generator = Random.bounded_i32(-7, -7)

	test_passes_with_many_seeds(
		|seed_num| {
			actual = Random.step(Random.seed(seed_num), i32_generator).value
			actual == -7
		},
	)
}

expect {
	u32_generator = Random.bounded_u32(0, 0)

	test_passes_with_many_seeds(
		|seed_num| {
			actual = Random.step(Random.seed(seed_num), u32_generator).value
			actual == 0
		},
	)
}

# test large ranges to avoid overflow when calculating difference between min and max
expect {
	test_seed = Random.seed(6)
	_ = Random.bounded_i32(I32.lowest, I32.highest - 1)(test_seed)
	_ = Random.bounded_i32(I32.highest, I32.lowest)(test_seed)
	_ = Random.bounded_u32(U32.lowest, U32.highest - 1)(test_seed)
	_ = Random.bounded_u32(U32.highest, U32.lowest)(test_seed)
	True
}

# test shuffle
expect {
	items = List.from_iter((0..<100).iter())
	expected_sum = items.sum()

	test_passes_with_many_seeds(
		|seed_num| {
			this_seed = Random.seed(seed_num)
			{ value: shuffled_items, .. } =
				Random.shuffle(items)(this_seed)
			actual_sum = shuffled_items.sum()

			actual_sum == expected_sum
		},
	)
}

# record builder and `Random.list` agree
expect {
	initial_state = Random.seed(33)

	record_generator = {
		n1: Random.u32,
		n2: Random.u32,
		n3: Random.u32,
		n4: Random.u32,
		n5: Random.u32,
		n6: Random.u32,
	}.Random

	record = record_generator(initial_state)
	{ n1, n2, n3, n4, n5, n6 } = record.value

	list = Random.list(Random.u32, 6)(initial_state)

	[n1, n2, n3, n4, n5, n6] == list.value and record.state == list.state
}

# Random.list same as multiple single value generators
expect {
	initial_state = Random.seed(5)

	n1 = Random.u32(initial_state)
	n2 = Random.u32(n1.state)

	n_list_again = Random.list(Random.u32, 2)(initial_state)

	n2.state == n_list_again.state
}

# "Known Answer Test" code ported from PCG C test from https://github.com/imneme/pcg-c
# `test-low/check-base.c`
pcg_c_known_answer_test_generator : Generator(Str)
pcg_c_known_answer_test_generator = |state| {
	u32_to_hex_str : U32 -> Str
	u32_to_hex_str = |n| {
		digits =
			(0..<32)
				.step_by(4)
				.iter()
				|> List.from_iter
				.rev()
				.map(
					|shift| {
						nibble = n.shr_zf_wrap(shift).bitwise_and(0xF).to_u8_wrap()
						if nibble < 10 {
							nibble + '0'
						} else {
							(nibble - 10) + 'a'
						}
					},
				)
		"0x${Str.from_utf8_lossy(digits)}"
	}

	card_to_str : U32 -> Str
	card_to_str = |n| {
		ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K']
		suits = ['h', 'c', 'd', 's']

		rank = (n // 4).to_u64()
		suit = (n % 4).to_u64()

		rank_char = match ranks.get(rank) {
			Ok(char) => char
			Err(OutOfBounds) => {
				crash "rank out of bounds"
			}
		}
		suit_char = match suits.get(suit) {
			Ok(char) => char
			Err(OutOfBounds) => {
				crash "suit out of bounds"
			}
		}

		Str.from_utf8_lossy([rank_char, suit_char])
	}

	deck_to_str : List(U32) -> Str
	deck_to_str = |deck| {
		groups = [
			deck.sublist({ start: 0, len: 22 }),
			deck.sublist({ start: 22, len: 22 }),
			deck.sublist({ start: 44, len: 22 }),
		]

		lines = groups.map(
			|group| {
				group.map(|card| " ${card_to_str(card)}") |> Str.join_with("")
			},
		)

		lines |> Str.join_with("\n\t")
	}

	test_round_to_str : TestRound, U64 -> Str
	test_round_to_str = |round, index| {
		{ u32_list, u32_list_again, coins, rolls, cards } = round

		u32_list_str = u32_list.map(u32_to_hex_str) |> Str.join_with(" ")
		u32_list_again_str = u32_list_again.map(u32_to_hex_str) |> Str.join_with(" ")
		coins_str = coins.map(|n| if (n == 0) 'T' else 'H') |> Str.from_utf8_lossy
		rolls_str = rolls.map(U32.to_str) |> Str.join_with(" ")
		cards_str = deck_to_str(cards)

		# the missing space on the cards string is intentional to match
		# janky formatting from the original PCG C test this was copied from
		\\Round ${(index + 1).to_str()}:
		\\  32bit: ${u32_list_str}
		\\  Again: ${u32_list_again_str}
		\\  Coins: ${coins_str}
		\\  Rolls: ${rolls_str}
		\\  Cards:${cards_str}
	}

	test_rounds =
		Random.list(test_round_generator, 5)(state)

	value =
		test_rounds.value.map_with_index(test_round_to_str) |> Str.join_with("\n\n")

	{ value, state: test_rounds.state }
}

# only included for parity with PCG-C known answer tests
shuffle_with_u32 : List(a) -> Generator(List(a))
shuffle_with_u32 = |items| {
	|var $state| {
		if items.len() < 2 return { value: items, state: $state }

		var $items = items
		for i in List.from_iter((1..<items.len()).iter()).rev() {
			{ value: choice_i, state: $state } =
				Random.bounded_u32(0, i.to_u32_wrap())($state)
			$items = match $items.swap(i, choice_i.to_u64()) {
				Ok(l) => l
				Err(OutOfBounds) => {
					crash "error in `shuffle_with_u32`"
					[]
				}
			}
		}

		{ value: $items, state: $state }
	}
}

TestRound : {
	u32_list : List(U32),
	u32_list_again : List(U32),
	coins : List(U32),
	rolls : List(U32),
	cards : List(U32),
}

test_round_generator : Generator(TestRound)
test_round_generator = |var $state| {
	{ value: u32_list, state: $state } =
		Random.list(Random.u32, 6)($state)

	$state = $state.rewind(6)

	{ value: u32_list_again, state: $state } =
		Random.list(Random.u32, 6)($state)

	{ value: coins, state: $state } =
		Random.list(Random.bounded_u32(0, 1), 65)($state)

	{ value: rolls, state: $state } =
		Random.list(Random.bounded_u32(1, 6), 33)($state)

	random_deck = shuffle_with_u32(List.from_iter((0..<52).iter()))
	{ value: cards, state: $state } =
		random_deck($state)

	{
		value: { u32_list, u32_list_again, coins, rolls, cards },
		state: $state,
	}
}

# expected answers from PCG C `test-low/expected/check-oneseq-32-rxs-m-xs-32.out`
expect {
	state = Random.seed(42)

	actual = pcg_c_known_answer_test_generator(state)

	expected =
		\\Round 1:
		\\  32bit: 0x256b5357 0xa5efad32 0x170b7830 0x334a5b22 0x3de5c680 0x9b47b7b3
		\\  Again: 0x256b5357 0xa5efad32 0x170b7830 0x334a5b22 0x3de5c680 0x9b47b7b3
		\\  Coins: HTHTHTHHHTTHTTTTTTHHTTTHHTTTHHTTHHTHTTHHTHHTTTTTHTTTHHHHHHHHTTTTT
		\\  Rolls: 5 5 5 1 5 6 5 1 3 4 5 3 4 5 4 5 2 5 6 4 5 4 4 5 5 6 4 3 6 3 5 4 5
		\\  Cards: 3c 5c Kc 6s Qh 7s Jh 4d 3s 5d 9h Th Qs 7h 4c 7c Qd 2d 3h 5h 2h 6c
		\\	 6d Js Jd 9d 8s 9s 9c Qc Kh 8d 8c 2s Tc 4s Ac 2c Jc Ks As Ah 6h Ad
		\\	 Ts 7d 3d 8h 5s Kd 4h Td
		\\
		\\Round 2:
		\\  32bit: 0xd3ea68f3 0x004a141a 0x08de95da 0xe6f4f6ad 0x1023b258 0x0fdabaa1
		\\  Again: 0xd3ea68f3 0x004a141a 0x08de95da 0xe6f4f6ad 0x1023b258 0x0fdabaa1
		\\  Coins: HTHHTTHHHTTHTTTHTTTHHTHHHHHHHHTHTTHHHHTTTHTTHHHHTTTHHTTHHTTTHHTTH
		\\  Rolls: 2 3 6 1 6 4 2 2 3 1 6 4 3 6 1 2 4 6 4 5 2 2 2 5 1 3 6 2 3 2 2 5 3
		\\  Cards: 6c Kc 5d Ac Tc 3c 7h Qh 7c 2c Kd 8c 2h Qs Qc 2s 6s Ts Jc 4h Ah 5c
		\\	 Qd 8d 4d Th 3d 7s 5s Jd 4c 9h 8h 6d 9c 9s 3s Td Js Kh 9d As 6h 3h
		\\	 2d Ks 4s 7d Jh Ad 5h 8s
		\\
		\\Round 3:
		\\  32bit: 0x6a106195 0xe06d41b2 0xbfd78624 0xe0ef944f 0x57571028 0x10aae72d
		\\  Again: 0x6a106195 0xe06d41b2 0xbfd78624 0xe0ef944f 0x57571028 0x10aae72d
		\\  Coins: HHTTHHTHTTTHHTHTHTHHHTTHHHTTHTTHTTHTTHTTHHTTTHHHTHTHTHHHHTHHTHTHH
		\\  Rolls: 4 6 1 3 1 6 6 1 4 5 1 5 5 6 2 4 6 5 2 5 4 6 4 3 5 2 3 6 6 3 1 2 5
		\\  Cards: 4d Jc 6d 2s 8c 7d Th 6h 5s 3c 3d Qd Ad 4h 2c 7s Tc 4s 3s Td 6s 9c
		\\	 2d 7c 8d 8h Jh Ts 4c 2h 5c 5h Ac 8s Qs Kh Kc 6c Qc 9h 9s 5d Kd Js
		\\	 Qh 3h 7h Ah As Jd 9d Ks
		\\
		\\Round 4:
		\\  32bit: 0xdde49a52 0x79306ca7 0x2bb1673c 0xfde1d6ff 0x0b261fe8 0xe866fced
		\\  Again: 0xdde49a52 0x79306ca7 0x2bb1673c 0xfde1d6ff 0x0b261fe8 0xe866fced
		\\  Coins: HHHHTTTTTTTTHTHTHHTTTHHTHTHHHHHTTTTTTTHTTHTTHTTHHHHHHTHTHTHTHHTTT
		\\  Rolls: 4 1 4 1 2 6 5 5 5 5 1 3 6 4 5 4 6 1 1 5 5 3 6 1 4 1 6 5 1 4 6 3 2
		\\  Cards: Td 7d 3h 2c 5s 6d Ac 8s Kc 5c 4s Qd 2s Kd As 6c 2d Kh 9c 3d 5d 3s
		\\	 Jd 8c 7s 4d 4h Qc 5h Js 7c 9s Ts Qh Ks 6s Th 8d 3c Tc 8h 9h Ad Jh
		\\	 Jc 9d 7h 2h Ah 6h 4c Qs
		\\
		\\Round 5:
		\\  32bit: 0x4253371d 0xcc6b3679 0xb8d7cd7d 0x9e7e0310 0xb1ee5e37 0x6cbff1d2
		\\  Again: 0x4253371d 0xcc6b3679 0xb8d7cd7d 0x9e7e0310 0xb1ee5e37 0x6cbff1d2
		\\  Coins: HHHTHHHTTHTTHTHHTHHTTHTTTHHTHHTTHHHTHHTTHTHHTTTTHTTHHHTTHHTHTTHTH
		\\  Rolls: 2 2 3 2 1 4 4 1 2 4 6 3 2 5 5 4 1 2 2 2 3 3 2 2 6 4 6 4 5 4 2 4 5
		\\  Cards: Kh 4d 8d 5h 4c 8s 3s Qc Js Td Jc 6c 5d 8h 9s 3h Kc Ac Tc 8c 6s 7h
		\\	 Jd 7c Ad Qd Jh 9d As 2c 6d 4h Kd 4s Qs 7s Qh 9h 3d 6h Ts Ks 7d 5c
		\\	 5s 9c 3c 2s 2h 2d Th Ah

	actual.value == expected
}

# expected answers from PCG C `test-low/expected/check-setseq-32-rxs-m-xs-32.out`
expect {
	state = Random.seed_variant(42, 54)

	actual = pcg_c_known_answer_test_generator(state)

	expected =
		\\Round 1:
		\\  32bit: 0xf84b622d 0xdc1e5bb4 0x74fb8ac1 0xb3bbf8de 0x9cf62074 0x2d2f5e33
		\\  Again: 0xf84b622d 0xdc1e5bb4 0x74fb8ac1 0xb3bbf8de 0x9cf62074 0x2d2f5e33
		\\  Coins: HTHHHHTTTTTHHHHHTTTTTHHTTTHTTHTHTTHTTTTTHTTTHHTHTTHTTHTTTTHTTHHHT
		\\  Rolls: 6 1 5 3 2 4 4 6 5 1 1 5 4 2 6 4 6 5 1 6 5 2 5 4 6 2 6 3 5 1 6 4 3
		\\  Cards: Kd 8h Td 9d As 4h 7s 5s 2s Js Qd 5h Ac 3d 8d 2d 3h 8s 7h Th 4d 9s
		\\	 Qc 3s Kc 6d 7c 9h 4c 8c Kh Jh Jc 4s 3c Ah Tc 6s 9c 7d 5c Ks 6c Qs
		\\	 Ad 6h Ts Jd 2h 2c 5d Qh
		\\
		\\Round 2:
		\\  32bit: 0xd6fdef4c 0xb793e894 0x62d8db75 0x51c7462c 0x9bbee1c9 0x9c609fb5
		\\  Again: 0xd6fdef4c 0xb793e894 0x62d8db75 0x51c7462c 0x9bbee1c9 0x9c609fb5
		\\  Coins: TTTHTHTTTHTTHTTHHTTTHHTHTHTHTTTTHTTHHTHTHHHHHTHHHHTHHTTTHHHTHHHTT
		\\  Rolls: 1 6 3 5 2 6 4 1 3 6 2 3 1 1 2 3 2 5 6 2 2 1 6 6 3 3 1 1 1 6 6 2 4
		\\  Cards: 6c Qd 9s 3d 7c 7h Ts 2c 3h Kd 2s Td 6h 8d Jh 2d 2h Ah 5h Th 5c 9c
		\\	 8s Kh As Kc 5s 6d Js Jd 4h 7d 5d Tc 8c Jc 6s 4s 9d 3c 4c Ac Qh Qs
		\\	 7s 4d 9h Ad Ks 8h 3s Qc
		\\
		\\Round 3:
		\\  32bit: 0x7e849685 0x0a1a7a41 0xcf53a482 0xcbc007c5 0x60e65898 0x9179fbd7
		\\  Again: 0x7e849685 0x0a1a7a41 0xcf53a482 0xcbc007c5 0x60e65898 0x9179fbd7
		\\  Coins: THHHHHHTTHHTHHTHHTHHTTHTHTTHHHTTHHHHHTHTHTHTTHTHTTHTHTHHTHTTHTTTH
		\\  Rolls: 6 1 4 4 3 4 6 3 2 5 3 5 2 2 6 6 3 4 6 4 6 1 3 2 2 3 2 2 3 6 2 1 4
		\\  Cards: Jd 8d 6c Jc 2s 9h 4d Kd 5d Qc Ts 8c 5s 3h 5h Ks 6d 4s 7c 5c Kc Js
		\\	 6s Kh Qs 7d 2c Ah 9d 3c 4c 4h 7h 9c 3s 3d As Tc Ac Ad 8s 8h Th Jh
		\\	 2d 6h Qd Qh 9s 7s 2h Td
		\\
		\\Round 4:
		\\  32bit: 0xcc53664c 0xe23c4863 0xa79bb6df 0x96f9b755 0x13a38786 0x34a8f727
		\\  Again: 0xcc53664c 0xe23c4863 0xa79bb6df 0x96f9b755 0x13a38786 0x34a8f727
		\\  Coins: TTTTHTHHTHHTTTHTHTHHHHTHHTTHHHHHHHTHTHHHTHTTTHTTHHHHHTHTTTHHHTHTT
		\\  Rolls: 4 1 5 6 2 3 1 5 4 2 4 4 5 2 1 5 2 6 6 5 2 6 2 1 2 5 3 1 4 6 5 3 3
		\\  Cards: Ad 9h 9d 5c 5d 5s 2s Ac Qs 4c 8s 6d Qh Kd 9c Ts 3d 4d Td 6h 4s 2h
		\\	 Jd 8h 7h Qd Ks Tc 7c 6s 8d As Kh Th Jh 3c 9s Kc Jc 3s 2c 8c 2d Js
		\\	 4h Ah 3h 5h 7d Qc 7s 6c
		\\
		\\Round 5:
		\\  32bit: 0x34c5b8b1 0x818c3828 0x23842fe4 0xd64649b8 0x5d1b76c9 0x18819107
		\\  Again: 0x34c5b8b1 0x818c3828 0x23842fe4 0xd64649b8 0x5d1b76c9 0x18819107
		\\  Coins: TTHHTHTTTHTHTTTTTHHTHTHTTTHHTTHTHTHHHHTTTHTTTTTTHHHTHTTTTHHTHTTTT
		\\  Rolls: 5 6 1 1 5 3 1 6 4 5 3 1 2 4 1 3 5 1 1 5 2 3 2 4 1 1 3 2 3 1 2 4 2
		\\  Cards: 3h 5h 7s 4h 3c 8h 2h Qc 8c 4d 6s 5d Jh Ad 6c 4c 7h Js 7d 6d 8s 9d
		\\	 2d Qs 3s Ts 2c 2s Ac 8d Th Kd 5s Kc 9c 7c 3d Td Jc As Tc Ks Qh Qd
		\\	 6h 9h 4s Jd 5c Ah 9s Kh

	actual.value == expected
}

# step forward odd
expect {
	initial_state = Random.seed(42)
	n = Random.u32(initial_state)

	actual = initial_state.fast_forward(1)
	expected = n.state

	actual == expected
}

# step backward small amount same as forward large amount
expect {
	initial_state = Random.seed(42)

	initial_state.rewind(1) == initial_state.fast_forward(U32.highest)
}

# repeat after backwards step
expect {
	initial_state = Random.seed(11)

	n1 = Random.u32(initial_state)
	n2 = Random.u32(n1.state.rewind(1))

	n1 == n2
}

expect {
	var $state = Random.seed(11)

	{ value: n1, state: $state } = Random.u32($state)
	$state = $state.rewind(1)
	{ value: n2, state: $state } = Random.u32($state)

	n1 == n2
}

# step backward even delta
expect {
	initial_state = Random.seed(1000)

	nums = Random.list(Random.u32, 2)(initial_state)

	nums_again = Random.list(Random.u32, 2)(nums.state.rewind(2))

	nums == nums_again
}

# step forward even delta
expect {
	initial_state = Random.seed(1000)

	nums = Random.list(Random.u32, 2)(initial_state)

	nums.state == initial_state.fast_forward(2)
}

# step forward with odd delta
expect {
	initial_state = Random.seed(1000)

	nums = Random.list(Random.u32, 3)(initial_state)

	nums.state == initial_state.fast_forward(3)
}

expect {
	state = Random.seed(0)

	same_state = state
		.fast_forward(1)
		.fast_forward(1)
		.fast_forward(2)
		.rewind(4)

	same_state == state
}

expect {
	test_passes_with_many_seeds(
		|s| {
			lo = -1000
			hi = -999
			{ value, .. } = Random.step(Random.seed(s), Random.f32(lo, hi))
			value >= lo and value < hi
		},
	)
}

expect {
	test_passes_with_many_seeds(
		|s| {
			lo = 1000
			hi = 1001
			{ value, .. } = Random.step(Random.seed(s), Random.f32(lo, hi))
			value >= lo and value < hi
		},
	)
}

expect {
	test_passes_with_many_seeds(
		|s| {
			lo = -1000
			hi = 5000
			{ value, .. } = Random.step(Random.seed(s), Random.f32(lo, hi))
			value >= lo and value < hi
		},
	)
}

expect {
	test_passes_with_many_seeds(
		|s| {
			lo = -0.1
			hi = 0.2
			{ value, .. } = Random.step(Random.seed(s), Random.f32(lo, hi))
			value >= lo and value < hi
		},
	)
}

expect {
	test_passes_with_many_seeds(
		|s| {
			lo = -1000
			hi = -999
			{ value, .. } = Random.step(Random.seed(s), Random.f64(lo, hi))
			value >= lo and value < hi
		},
	)
}

expect {
	test_passes_with_many_seeds(
		|s| {
			lo = 1000
			hi = 1001
			{ value, .. } = Random.step(Random.seed(s), Random.f64(lo, hi))
			value >= lo and value < hi
		},
	)
}

expect {
	test_passes_with_many_seeds(
		|s| {
			lo = -1000
			hi = 5000
			{ value, .. } = Random.step(Random.seed(s), Random.f64(lo, hi))
			value >= lo and value < hi
		},
	)
}

expect {
	test_passes_with_many_seeds(
		|s| {
			lo = -0.1
			hi = 0.2
			{ value, .. } = Random.step(Random.seed(s), Random.f32(lo, hi))
			value >= lo and value < hi
		},
	)
}

# Random.choice all choices eventually encountered
expect {
	choice_generator = Random.choice(A, [B, C])
	var $state = Random.seed(0)
	var $encountered_choices = Set.empty()
	for _ in 0..<100 {
		{ value: choice, state: $state } = choice_generator($state)
		$encountered_choices = $encountered_choices.insert(choice)
	}

	[A, B, C].all(|choice| $encountered_choices.contains(choice))
}

# Random.choice_try all choices eventually encountered
expect {
	choice_generator = Random.choice_try([A, B, C])?
	var $state = Random.seed(0)
	var $encountered_choices = Set.empty()
	for _ in 0..<100 {
		{ value: choice, state: $state } = choice_generator($state)
		$encountered_choices = $encountered_choices.insert(choice)
	}

	[A, B, C].all(|choice| $encountered_choices.contains(choice))
}

# Random.choice_weighted with very unlikely choice
# Not a fool-proof test but if it fails you should probably go buy a lottery ticket
expect {
	choice_generator = Random.choice_weighted((A, 0.0000000001), [(B, 1000000000), (C, 1000000000)])
	var $state = Random.seed(0)
	var $encountered_choices = Set.empty()
	for _ in 0..<100 {
		{ value: choice, state: $state } = choice_generator($state)
		$encountered_choices = $encountered_choices.insert(choice)
	}

	$encountered_choices.contains(A) == False and
		$encountered_choices.contains(B) and
			$encountered_choices.contains(C)
}

# Random.choice_weighted with even weights
expect {
	choice_generator = Random.choice_weighted((A, 1), [(B, 1), (C, 1)])
	var $state = Random.seed(0)
	var $encountered_choices = Set.empty()
	for _ in 0..<100 {
		{ value: choice, state: $state } = choice_generator($state)
		$encountered_choices = $encountered_choices.insert(choice)
	}

	[A, B, C].all(|choice| $encountered_choices.contains(choice))
}

# Random.choice_weighted_try with even weights
expect {
	choice_generator = Random.choice_weighted_try([(A, 1), (B, 1), (C, 1)])?
	var $state = Random.seed(0)
	var $encountered_choices = Set.empty()
	for _ in 0..<100 {
		{ value: choice, state: $state } = choice_generator($state)
		$encountered_choices = $encountered_choices.insert(choice)
	}

	[A, B, C].all(|choice| $encountered_choices.contains(choice))
}

expect {
	state = Random.seed(0)
	generator = Random.chain(
		Random.static(3),
		|count| {
			Random.list(Random.static(4), count)
		},
	)

	{ value, .. } = generator(state)
	value == [4, 4, 4]
}

expect step_down_f32(0.0) == F32.from_bits(0x8000_0000)
expect step_down_f32(F32.infinity) == F32.highest
expect step_down_f32(-(F32.infinity)) == -(F32.infinity)
expect step_down_f32(F32.lowest) == -(F32.infinity)
expect step_down_f32(F32.nan).is_nan()
expect step_down_f32(1.0) < 1.0
expect step_down_f32(-1.0) < -1.0

expect step_down_f64(0.0) == F64.from_bits(0x8000_0000_0000_0000)
expect step_down_f64(F64.infinity) == F64.highest
expect step_down_f64(-(F64.infinity)) == -(F64.infinity)
expect step_down_f64(F64.lowest) == -(F64.infinity)
expect step_down_f64(F64.nan).is_nan()
expect step_down_f64(1.0) < 1.0
expect step_down_f64(-1.0) < -1.0
