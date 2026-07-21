app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	rand: "https://github.com/kili-ilo/roc-random/releases/download/0.7.1/CQxsugKpN13qpgSGgsNBSA28dhjU5VskQVgEcbHmur5p.tar.zst",
}

import pf.Stdout
import rand.Random

# Print a list of 10 random numbers in the range 25-75 inclusive.
main! = |_args| {
	numbers_generator = Random.list(Random.bounded_u32(25, 75), 10)
	{ value: random_numbers, .. } = Random.step(Random.seed(1234), numbers_generator)

	Stdout.line!(Str.join_with(random_numbers.map(U32.to_str), "\n"))
	Ok({})
}

expect {
	numbers_generator = Random.list(Random.bounded_u32(25, 75), 10)
	{ value: random_numbers, .. } = Random.step(Random.seed(1234), numbers_generator)

	random_numbers == [59, 62, 67, 63, 41, 52, 44, 72, 42, 48]
}
