app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	rand: "../package/main.roc",
}

import pf.Stdout
import rand.Random

roll_count : U64
roll_count = 5

rolls_from_seed : U32 -> List(U8)
rolls_from_seed = |seed_num| {
	dice = Random.list(Random.bounded_u8(1, 6), roll_count)

	Random.step(Random.seed(seed_num), dice).value
}

total : List(U8) -> U32
total = |rolls|
	rolls.fold(0, |sum, roll| sum + roll.to_u32())

rolls_to_str : List(U8) -> Str
rolls_to_str = |rolls|
	Str.join_with(rolls.map(U8.to_str), ", ")

main! = |_args| {
	rolls = rolls_from_seed(2026)

	Stdout.line!("Rolls: ${rolls_to_str(rolls)}")
	Stdout.line!("Total: ${U32.to_str(total(rolls))}")
	Ok({})
}

expect {
	rolls = rolls_from_seed(2026)

	rolls == [1, 3, 3, 1, 5] and total(rolls) == 13
}
