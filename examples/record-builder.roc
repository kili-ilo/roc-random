app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	rand: "https://github.com/kili-ilo/roc-random/releases/download/0.6.0/4mHqd7aiQ1hYkoso9C8JRfnx3GuwcwoDqv8EdqAsLbfN.tar.zst",
}

import pf.Stdout
import rand.Random

Character : {
	name : Str,
	strength : U8,
	agility : U8,
	hit_points : U8,
	lucky : Bool,
}

character_generator : Str -> Random.Generator(Character)
character_generator = |name| {
	d20 = Random.bounded_u8(1, 20)
	lucky_generator = Random.map(Random.bounded_u8(1, 20), |roll| roll == 20)

	{
		name: Random.static(name),
		strength: d20,
		agility: d20,
		hit_points: Random.bounded_u8(8, 16),
		lucky: lucky_generator,
	}.Random
}

character_from_seed : Str, U32 -> Character
character_from_seed = |name, seed_num|
	Random.step(Random.seed(seed_num), character_generator(name)).value

main! = |_args| {
	character = character_from_seed("Ada", 9001)

	Stdout.line!("Character: ${Str.inspect(character)}")
	Ok({})
}

expect character_from_seed("Ada", 9001) == { name: "Ada", strength: 3, agility: 3, hit_points: 13, lucky: False }
