app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	rand: "../package/main.roc",
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

	actual = random_numbers
	actual == [66, 43, 43, 27, 65, 75, 58, 34, 61, 75]
}
