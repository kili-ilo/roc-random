app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	rand: "https://github.com/kili-ilo/roc-random/releases/download/0.7.0/2LdxsJEfiBKwTBZc8SF1SidGC68wKCvfAwVREwWKwZu7.tar.zst",
}

import pf.Stdout
import rand.Random

stream_from_variant : U32 -> List(U32)
stream_from_variant = |update_increment| {
	numbers = Random.list(Random.bounded_u32(0, 99), 4)

	Random.step(Random.seed_variant(1234, update_increment), numbers).value
}

numbers_to_str : List(U32) -> Str
numbers_to_str = |numbers|
	Str.join_with(numbers.map(U32.to_str), ", ")

main! = |_args| {
	default_stream = stream_from_variant(2_891_336_453)
	variant_a = stream_from_variant(1)
	variant_b = stream_from_variant(3)

	Stdout.line!("Default: ${numbers_to_str(default_stream)}")
	Stdout.line!("Variant A: ${numbers_to_str(variant_a)}")
	Stdout.line!("Variant B: ${numbers_to_str(variant_b)}")
	Ok({})
}

expect {
	default_stream = stream_from_variant(2_891_336_453)
	variant_a = stream_from_variant(1)
	variant_b = stream_from_variant(3)

	default_stream == [39, 32, 79, 9] and variant_a == [19, 17, 87, 34] and variant_b == [49, 31, 72, 62]
}
