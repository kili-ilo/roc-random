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
	State :: { s : U32, update_increment : U32 }

	## Construct an initial "seed" `State` for `Generator`s
	seed : U32 -> State
	seed = |initial_seed| {
		default_sequence_id = U32.shift_right_zf_by(default_u32_update_increment, 1)
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
		update_increment = sequence_id.shift_left_by(1).bitwise_or(1)

		var $seed = State.({ s: 0, update_increment })
		$seed = $seed->update()
		$seed = { ..$seed, s: $seed.s + initial_seed }
		$seed->update()
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
	list = |generator, length| {
		|state| {
			var $state = state
			var $result = List.with_capacity(length)

			for _ in 0..<length {
				{ value: item, state: $state } = generator($state)
				$result = $result.append(item)
			}

			{ value: $result, state: $state }
		}
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
	bounded_u8 = |x, y| bounded_u32_helper(x, y)->map(U32.to_u8_wrap)

	## Construct a `Generator` for 8-bit signed integers
	i8 : Generator(I8)
	i8 = u32->map(U32.to_i8_wrap)

	## Construct a `Generator` for 8-bit signed integers between two boundaries (inclusive)
	bounded_i8 : I8, I8 -> Generator(I8)
	bounded_i8 = |x, y| bounded_i32_helper(x, y)->map(I32.to_i8_wrap)

	## Construct a `Generator` for 16-bit unsigned integers
	u16 : Generator(U16)
	u16 = u32->map(U32.to_u16_wrap)

	## Construct a `Generator` for 16-bit unsigned integers between two boundaries (inclusive)
	bounded_u16 : U16, U16 -> Generator(U16)
	bounded_u16 = |x, y| bounded_u32_helper(x, y)->map(U32.to_u16_wrap)

	## Construct a `Generator` for 16-bit signed integers
	i16 : Generator(I16)
	i16 = u32->map(U32.to_i16_wrap)

	## Construct a `Generator` for 16-bit signed integers between two boundaries (inclusive)
	bounded_i16 : I16, I16 -> Generator(I16)
	bounded_i16 = |x, y| bounded_i32_helper(x, y)->map(I32.to_i16_wrap)

	## Construct a `Generator` for 32-bit unsigned integers
	u32 : Generator(U32)
	u32 = |state| {
		value = state->permute()
		next_state = state->update()

		{ value, state: next_state }
	}

	## Construct a `Generator` for 32-bit unsigned integers between two boundaries (inclusive)
	bounded_u32 : U32, U32 -> Generator(U32)
	bounded_u32 = bounded_u32_helper

	## Construct a `Generator` for 32-bit signed integers
	i32 : Generator(I32)
	i32 = u32->map(U32.to_i32_wrap)

	## Construct a `Generator` for 32-bit signed integers between two boundaries (inclusive)
	bounded_i32 : I32, I32 -> Generator(I32)
	bounded_i32 = bounded_i32_helper
}

# Helpers for the above constructors -------------------------------------------

## Generate a random U32 in the range `[0, range)` returning the new state of
## the backing PCG See [www.pcg-random.org/posts/bounded-rands.html](https://www.pcg-random.org/posts/bounded-rands.html)
## Ported from PCG-C implementation. If a truly random generator was backing
## this, technically there would be a very very slim chance of this while loop
## never terminating, but because the backing PCG in this implimentation is well
## distributed in its values over time, it will quickly find a value that
## doesn't suffer from a bias toward lower numbers in the range.
## The pathological value for `range` is slightly larger than `2**31` causing
## almost half of generated candidates to be rejected. In practice, with small
## `range` values, there is an extremely miniscule chance of generating even a
## single value that needs to be rejected.
##
u32_exclusive_range_unbiased : State, int -> { value : U32, state : State } where [int.to_u32 : int -> U32]
u32_exclusive_range_unbiased = |state, range| {
	range_u32 = range.to_u32()
	threshold = negate_wrap_u32(range_u32) % range_u32

	var $state = state
	while True {
		x = $state->permute()
		$state = $state->update()
		if x >= threshold {
			return { value: x % range_u32, state: $state }
		}
	}
}

bounded_u32_helper : int, int -> Generator(U32) where [int.to_u32 : int -> U32]
bounded_u32_helper = |x, y| {
	(minimum, maximum) = sort(x.to_u32(), y.to_u32())

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

bounded_i32_helper : int, int -> Generator(I32) where [int.to_i32 : int -> I32]
bounded_i32_helper = |x, y| {
	(minimum, maximum) = sort(x.to_i32(), y.to_i32())
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

sort = |x, y|
	if x < y {
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
			.shift_right_zf_by(shift_amount)
			.to_u8_wrap()
	}

	partial1 = state->xor_shift(rxs_shift_op + rxs_op_bitcount)
	partial2 = partial1->mul_wrap_u32(default_u32_permute_multiplier)

	final_xor_shift_amount = ((2 * output_bitcount) + 2) // 3
	partial2->xor_shift(final_xor_shift_amount)
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

## Step the random state forward by n steps. The sequence has a period of
## 2 to the 32 steps, and will wrap around after that.
step_forward : Random.State, U32 -> Random.State
step_forward = |state, delta| {
	var $acc_mult = 1.U32
	var $acc_plus = 0.U32
	var $cur_mult = default_u32_update_multiplier
	var $cur_plus = state.update_increment
	var $delta = delta

	while $delta > 0 {
		if $delta % 2 == 1 {
			$acc_mult = mul_wrap_u32($acc_mult, $cur_mult)
			$acc_plus = 
				mul_wrap_u32($acc_plus, $cur_mult)
					->add_wrap_u32($cur_plus)
		}
		$cur_plus = 
			add_wrap_u32($cur_mult, 1)
				->mul_wrap_u32($cur_plus)
		$cur_mult = mul_wrap_u32($cur_mult, $cur_mult)
		$delta = $delta // 2
	}

	next_s = 
		mul_wrap_u32(state.s, $acc_mult)
			->add_wrap_u32($acc_plus)

	{ ..state, s: next_s }
}

step_backward : Random.State, U32 -> Random.State
step_backward = |state, delta| step_forward(state, negate_wrap_u32(delta))

# Common math helpers

xor_shift : U32, U8 -> U32
xor_shift = |value, shift_amount| {
	shifted = value.shift_right_zf_by(shift_amount)
	value.bitwise_xor(shifted)
}

add_wrap_u32 : U32, U32 -> U32
add_wrap_u32 = |a, b| (a.to_u64() + b.to_u64()).to_u32_wrap()

add_wrap_i32 : I32, I32 -> I32
add_wrap_i32 = |a, b| (a.to_i64() + b.to_i64()).to_i32_wrap()

mul_wrap_u32 : U32, U32 -> U32
mul_wrap_u32 = |a, b| (a.to_u64() * b.to_u64()).to_u32_wrap()

negate_wrap_u32 : U32 -> U32
negate_wrap_u32 = |a| a.bitwise_not()->add_wrap_u32(1)

# Tests

expect {
	always_five = Random.static(5)
	Iter.fold(
		0..<100,
		True,
		|all_passed, seed_num| {
			this_seed = Random.seed(seed_num)
			rand_generation = Random.step(this_seed, always_five)

			all_passed and rand_generation.value == 5
		},
	)
}

expect {
	doubled_int = Random.bounded_i32(-100, 100)->Random.map(|i| i * 2)

	Iter.fold(
		0..<100,
		True,
		|all_passed, seed_num| {
			this_seed = Random.seed(seed_num)
			rand_generation = Random.step(this_seed, Random.bounded_i32(-100, 100))
			doubled_rand_generation = Random.step(this_seed, doubled_int)
			rand_int = rand_generation.value
			doubled_rand_int = doubled_rand_generation.value

			all_passed and rand_int * 2 == doubled_rand_int
		},
	)
}

expect {
	color_component_gen = Random.bounded_i32(0, 255)
	rgb_generator = { r: color_component_gen, g: color_component_gen, b: color_component_gen }.Random

	Iter.fold(
		0..<100,
		True,
		|all_passed, seed_num| {
			this_seed = Random.seed(seed_num)
			{ value: color, .. } = Random.step(this_seed, rgb_generator)
			{ r, g, b } = color
			all_passed and r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255
		},
	)
}

# sanity check for non-bounded generators, checking for overflows/crashes etc
expect {
	unbounded_values = {
		a: Random.u8,
		b: Random.i8,
		c: Random.u16,
		d: Random.i16,
		e: Random.u32,
		f: Random.i32,
	}.Random

	test_seed = Random.seed(123)

	_ = unbounded_values(test_seed)

	True
}

expect {
	ascending_bounded = Random.bounded_u8(90, 200)
	descending_bounded = Random.bounded_u8(200, 90)
	Iter.fold(
		0..<100,
		True,
		|all_passed, seed_num| {
			this_seed = Random.seed(seed_num)
			{ value: value_a, .. } = Random.step(this_seed, ascending_bounded)
			{ value: value_b, .. } = Random.step(this_seed, descending_bounded)
			all_passed and value_a >= 90 and value_a <= 200 and value_a == value_b
		},
	)
}

expect {
	ascending_bounded = Random.bounded_u16(200, 33000)
	descending_bounded = Random.bounded_u16(33000, 200)
	Iter.fold(
		0..<100,
		True,
		|all_passed, seed_num| {
			this_seed = Random.seed(seed_num)
			{ value: value_a, .. } = Random.step(this_seed, ascending_bounded)
			{ value: value_b, .. } = Random.step(this_seed, descending_bounded)
			all_passed and value_a >= 200 and value_a <= 33000 and value_a == value_b
		},
	)
}

expect {
	ascending_bounded = Random.bounded_u32(20_000_000, 30_000_000)
	descending_bounded = Random.bounded_u32(30_000_000, 20_000_000)
	Iter.fold(
		0..<100,
		True,
		|all_passed, seed_num| {
			this_seed = Random.seed(seed_num)
			{ value: value_a, .. } = Random.step(this_seed, ascending_bounded)
			{ value: value_b, .. } = Random.step(this_seed, descending_bounded)
			all_passed and value_a >= 20_000_000 and value_a <= 30_000_000 and value_a == value_b
		},
	)
}

expect {
	ascending_bounded = Random.bounded_i8(-100, 120)
	descending_bounded = Random.bounded_i8(120, -100)
	Iter.fold(
		0..<100,
		True,
		|all_passed, seed_num| {
			this_seed = Random.seed(seed_num)
			{ value: value_a, .. } = Random.step(this_seed, ascending_bounded)
			{ value: value_b, .. } = Random.step(this_seed, descending_bounded)
			all_passed and value_a >= -100 and value_a <= 120 and value_a == value_b
		},
	)
}

expect {
	ascending_bounded = Random.bounded_i16(-1000, 1000)
	descending_bounded = Random.bounded_i16(1000, -1000)
	Iter.fold(
		0..<100,
		True,
		|all_passed, seed_num| {
			this_seed = Random.seed(seed_num)
			{ value: value_a, .. } = Random.step(this_seed, ascending_bounded)
			{ value: value_b, .. } = Random.step(this_seed, descending_bounded)
			all_passed and value_a >= -1000 and value_a <= 1000 and value_a == value_b
		},
	)
}

expect {
	ascending_bounded = Random.bounded_i32(-40_000_000, 70_000_000)
	descending_bounded = Random.bounded_i32(70_000_000, -40_000_000)
	Iter.fold(
		0..<100,
		True,
		|all_passed, seed_num| {
			this_seed = Random.seed(seed_num)
			{ value: value_a, .. } = Random.step(this_seed, ascending_bounded)
			{ value: value_b, .. } = Random.step(this_seed, descending_bounded)
			all_passed and value_a >= -40_000_000 and value_a <= 70_000_000 and value_a == value_b
		},
	)
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

# test large ranges to avoid overflow when calculating difference between min and max
expect {
	test_seed = Random.seed(6)
	_ = Random.bounded_i32(I32.lowest, I32.highest - 1)(test_seed)
	_ = Random.bounded_i32(I32.highest, I32.lowest)(test_seed)
	_ = Random.bounded_u32(U32.lowest, U32.highest - 1)(test_seed)
	_ = Random.bounded_u32(U32.highest, U32.lowest)(test_seed)
	True
}

# "Known Answer Test" code ported from PCG C test from https://github.com/imneme/pcg-c
# `test-low/check-base.c`
pcg_c_known_answer_test_generator : Generator(Str)
pcg_c_known_answer_test_generator = |state| {
	u32_to_hex_str : U32 -> Str
	u32_to_hex_str = |n| {
		digits = (0..<32).step_by(4).rev().map(
			|shift| {
				nibble = n.shift_right_by(shift).bitwise_and(0xF).to_u8_wrap()
				if nibble < 10 {
					nibble + '0'
				} else {
					(nibble - 10) + 'a'
				}
			},
		).collect()
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
				group.map(|card| " ${card_to_str(card)}")->Str.join_with("")
			},
		)

		lines->Str.join_with("\n\t")
	}

	test_round_to_str : TestRound, U64 -> Str
	test_round_to_str = |round, index| {
		{ u32_list, u32_list_again, coins, rolls, cards } = round

		u32_list_str = u32_list.map(u32_to_hex_str)->Str.join_with(" ")
		u32_list_again_str = u32_list_again.map(u32_to_hex_str)->Str.join_with(" ")
		coins_str = coins.map(|n| if (n == 0) 'T' else 'H')->Str.from_utf8_lossy()
		rolls_str = rolls.map(U32.to_str)->Str.join_with(" ")
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
		test_rounds.value.map_with_index(test_round_to_str)->Str.join_with("\n\n")

	{ value, state: test_rounds.state }
}

shuffled_deck_generator : Generator(List(U32))
shuffled_deck_generator = |state| {
	var $state = state
	var $deck = (0..<52).collect()

	for i in (1..<$deck.len()).rev() {
		{ value: choice_i, state: $state } = 
			Random.bounded_u32(0, i.to_u32_wrap())($state)
		$deck = match $deck.swap(i, choice_i.to_u64()) {
			Ok(l) => l
			Err(OutOfBounds) => {
				crash "error in `shuffled_deck_generator`"
				[]
			}
		}
	}

	{ value: $deck, state: $state }
}

TestRound : {
	u32_list : List(U32),
	u32_list_again : List(U32),
	coins : List(U32),
	rolls : List(U32),
	cards : List(U32),
}

test_round_generator : Generator(TestRound)
test_round_generator = |state| {
	var $state = state

	{ value: u32_list, state: $state } = 
		Random.list(Random.u32, 6)($state)

	$state = $state->step_backward(6)

	{ value: u32_list_again, state: $state } = 
		Random.list(Random.u32, 6)($state)

	{ value: coins, state: $state } = 
		Random.list(Random.bounded_u32(0, 1), 65)($state)

	{ value: rolls, state: $state } = 
		Random.list(Random.bounded_u32(1, 6), 33)($state)

	{ value: cards, state: $state } = 
		shuffled_deck_generator($state)

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

	actual = initial_state->step_forward(1)
	expected = n.state

	actual == expected
}

# step backward small amount same as forward large amount
expect {
	initial_state = Random.seed(42)

	initial_state->step_backward(1) == initial_state->step_forward(U32.highest)
}

# repeat after backwards step
expect {
	initial_state = Random.seed(11)

	n1 = Random.u32(initial_state)
	n2 = Random.u32(n1.state->step_backward(1))

	n1 == n2
}

expect {
	var $state = Random.seed(11)

	{ value: n1, state: $state } = Random.u32($state)
	$state = $state->step_backward(1)
	{ value: n2, state: $state } = Random.u32($state)

	n1 == n2
}

# record generator and list agree on values
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

	[n1, n2, n3, n4, n5, n6] == list.value
}

# record generator and list agree on state
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
	list = Random.list(Random.u32, 6)(initial_state)

	record.state == list.state
}

# Random.list same as multiple single value generators
expect {
	initial_state = Random.seed(5)

	n1 = Random.u32(initial_state)
	n2 = Random.u32(n1.state)

	n_list_again = Random.list(Random.u32, 2)(initial_state)

	n2.state == n_list_again.state
}

# step backward even delta
expect {
	initial_state = Random.seed(1000)

	nums = Random.list(Random.u32, 2)(initial_state)

	nums_again = Random.list(Random.u32, 2)(nums.state->step_backward(2))

	nums == nums_again
}

# step forward even delta
expect {
	initial_state = Random.seed(1000)

	nums = Random.list(Random.u32, 2)(initial_state)

	nums.state == initial_state->step_forward(2)
}

# step forward with odd delta
expect {
	initial_state = Random.seed(1000)

	nums = Random.list(Random.u32, 3)(initial_state)

	nums.state == initial_state->step_forward(3)
}

expect {
	state = Random.seed(0)

	same_state = state
		->step_forward(1)
		->step_forward(1)
		->step_forward(2)
		->step_backward(4)

	same_state == state
}
