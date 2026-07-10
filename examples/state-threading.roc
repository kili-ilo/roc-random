app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	rand: "../package/main.roc",
}

import pf.Stdout
import rand.Random

Turn : {
	attack : U32,
	block : U32,
	critical_roll : U8,
}

turn_from_seed : U32 -> Turn
turn_from_seed = |seed_num| {
	attack = Random.step(Random.seed(seed_num), Random.bounded_u32(6, 12))
	block = Random.next(attack, Random.bounded_u32(0, 5))
	critical_roll = Random.next(block, Random.bounded_u8(1, 20))

	{
		attack: attack.value,
		block: block.value,
		critical_roll: critical_roll.value,
	}
}

main! = |_args| {
	turn = turn_from_seed(123)

	Stdout.line!("Turn: ${Str.inspect(turn)}")
	Ok({})
}

expect turn_from_seed(123) == { attack: 12, block: 4, critical_roll: 6 }
