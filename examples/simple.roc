app [main!] {
	rand: "https://github.com/kili-ilo/roc-random/releases/download/0.9.3/HoULZB8QzktiNPYSe9myzy9JQzm1nMbjDPVWoA63QpVf.tar.zst",
	roc: "nightly-2026-11-10-f7d1f19",
}

import rand.Random

# Seed value to generate random numbers
seed = Random.seed(1234)

main! = |_args| {
	# Generate a random number in the range 25-75 inclusive and convert it to a Str
	generator = Random.map(Random.bounded_u32(25, 75), U32.to_str)
	{ value, .. } = Random.step(seed, generator)

	echo!("Random number is ${value}\n")
	Ok({})
}

expect {
	generator = Random.map(Random.bounded_u32(25, 75), U32.to_str)
	generation = Random.step(seed, generator)
	generation.value == "59"
}
