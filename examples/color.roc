app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	rand: "https://github.com/kili-ilo/roc-random/releases/download/0.9.2/2ZXLX8WRqrosGu1V3VL5aXqgtfTRvJmjFPx8a26ecVmc.tar.zst",
	roc: "nightly-2026-08-25-cc03aa8",
}

import pf.Stdout
import rand.Random

Color : { red : U8, green : U8, blue : U8, alpha : U8 }

seed = Random.seed(12345)

color_generator : Random.Generator(Color)
color_generator = {
	red: Random.u8,
	green: Random.u8,
	blue: Random.u8,
	alpha: Random.u8,
}.Random

main! = |_args| {
	{ value: color, .. } = Random.step(seed, color_generator)
	Stdout.line!("Color generated: ${Str.inspect(color)}")
	Ok({})
}

expect {
	{ value: color, .. } = Random.step(seed, color_generator)
	color == { red: 136, green: 236, blue: 172, alpha: 78 }
}
