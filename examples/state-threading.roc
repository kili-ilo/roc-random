app [main!] {
	rand: "https://github.com/kili-ilo/roc-random/releases/download/0.9.3/HoULZB8QzktiNPYSe9myzy9JQzm1nMbjDPVWoA63QpVf.tar.zst",
	roc: "nightly-2026-11-12-ce942d6",
}

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

	echo!("Turn: ${Str.inspect(turn)}\n")
	Ok({})
}

expect {
	turn = turn_from_seed(123)
	turn == { attack: 12, block: 1, critical_roll: 14 }
}
