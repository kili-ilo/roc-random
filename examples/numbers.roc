app [main!] {
	rand: "https://github.com/kili-ilo/roc-random/releases/download/0.9.3/HoULZB8QzktiNPYSe9myzy9JQzm1nMbjDPVWoA63QpVf.tar.zst",
	roc: "nightly-2026-11-10-f7d1f19",
}

import rand.Random

# Print a list of 10 random numbers in the range 25-75 inclusive.
main! = |_args| {
	numbers_generator = Random.list(Random.bounded_u32(25, 75), 10)
	{ value: random_numbers, .. } = Random.step(Random.seed(1234), numbers_generator)

	for number in random_numbers {
		echo!("${U32.to_str(number)}\n")
	}
	Ok({})
}

expect {
	numbers_generator = Random.list(Random.bounded_u32(25, 75), 10)
	{ value: random_numbers, .. } = Random.step(Random.seed(1234), numbers_generator)

	random_numbers == [59, 62, 67, 63, 41, 52, 44, 72, 42, 48]
}
