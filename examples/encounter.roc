app [main!] {
	rand: "https://github.com/kili-ilo/roc-random/releases/download/0.9.3/HoULZB8QzktiNPYSe9myzy9JQzm1nMbjDPVWoA63QpVf.tar.zst",
	roc: "nightly-2026-11-12-ce942d6",
}

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

	echo!("Encounter: ${Str.inspect(encounter)}\n")
	Ok({})
}

expect {
	encounter = encounter_from_seed(99)
	encounter == { enemies: 2, treasure: 151, x: -4, y: -4 }
}
