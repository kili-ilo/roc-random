app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	rand: "../package/main.roc",
}

import pf.Stdout
import rand.Random

# Seed value to generate random numbers
seed = Random.seed(1234)

main! = |_args| {
	# Generate a random number in the range 25-75 inclusive and convert it to a Str
	generator = Random.map(Random.bounded_u32(25, 75), U32.to_str)
	{ value, .. } = Random.step(seed, generator)

	Stdout.line!("Random number is ${value}")
	Ok({})
}

expect {
	generator = Random.map(Random.bounded_u32(25, 75), U32.to_str)
	generation = Random.step(seed, generator)
	generation.value == "59"
}
