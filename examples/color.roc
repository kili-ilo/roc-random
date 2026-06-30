app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	rand: "https://github.com/kili-ilo/roc-random/releases/download/0.6.0/4mHqd7aiQ1hYkoso9C8JRfnx3GuwcwoDqv8EdqAsLbfN.tar.zst",
}

import pf.Stdout
import rand.Random

Color : { red : U8, green : U8, blue : U8, alpha : U8 }

seed = Random.seed(12345)

main! = |_args| {
	color_generator : Random.Generator(Color)
	color_generator = {
		red: Random.u8,
		green: Random.u8,
		blue: Random.u8,
		alpha: Random.u8,
	}.Random

	{ value: color, .. } = Random.step(seed, color_generator)
	Stdout.line!("Color generated: ${Str.inspect(color)}")
	Ok({})
}
