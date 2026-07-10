app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	rand: "../package/main.roc",
}

import pf.Stdout
import rand.Random

Encounter : {
	enemies : U8,
	treasure : U32,
	x : I32,
	y : I32,
}

encounter_from_seed : U32 -> Encounter
encounter_from_seed = |seed_num| {
	encounter_generator : Random.Generator(Encounter)
	encounter_generator = {
		enemies: Random.bounded_u8(1, 4),
		treasure: Random.bounded_u32(25, 250),
		x: Random.bounded_i32(-10, 10),
		y: Random.bounded_i32(-10, 10),
	}.Random

	Random.step(Random.seed(seed_num), encounter_generator).value
}

main! = |_args| {
	encounter = encounter_from_seed(99)

	Stdout.line!("Encounter: ${Str.inspect(encounter)}")
	Ok({})
}

expect encounter_from_seed(99) == { enemies: 2, treasure: 212, x: -8, y: -6 }
