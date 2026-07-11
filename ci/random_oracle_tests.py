#!/usr/bin/env python3
from __future__ import annotations

import ast
import os
import random
import subprocess
import sys
import tempfile
import time
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ROC = os.environ.get("ROC", "roc")
MASK_U32 = 0xFFFF_FFFF
U32_SIZE = 1 << 32
I32_LOWEST = -(1 << 31)
I32_HIGHEST = (1 << 31) - 1

DEFAULT_PERMUTE_MULTIPLIER = 277_803_737
DEFAULT_PERMUTE_RANDOM_XOR_SHIFT = 28
DEFAULT_PERMUTE_RANDOM_XOR_SHIFT_INCREMENT = 4
DEFAULT_PERMUTE_XOR_SHIFT = 22
DEFAULT_UPDATE_INCREMENT = 2_891_336_453
DEFAULT_UPDATE_MULTIPLIER = 747_796_405

PLATFORM_URL = (
    "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/"
    "0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst"
)


@dataclass(frozen=True)
class State:
    value: int
    increment: int = DEFAULT_UPDATE_INCREMENT


@dataclass(frozen=True)
class Case:
    name: str
    mode: str
    seed: int
    increment: int
    count: int
    low: int | None = None
    high: int | None = None


def u32(value: int) -> int:
    return value & MASK_U32


def to_i32_wrap(value: int) -> int:
    wrapped = u32(value)
    if wrapped > I32_HIGHEST:
        return wrapped - U32_SIZE
    return wrapped


def shift_right_zf_by_u32(value: int, shift: int) -> int:
    return u32(value) >> (shift % 32)


def permute(state: State) -> int:
    inner_shifted = shift_right_zf_by_u32(DEFAULT_PERMUTE_RANDOM_XOR_SHIFT, state.value)
    inner_shift = u32(inner_shifted + DEFAULT_PERMUTE_RANDOM_XOR_SHIFT_INCREMENT)
    inner = shift_right_zf_by_u32(inner_shift, state.value)
    partial = u32((state.value ^ inner) * DEFAULT_PERMUTE_MULTIPLIER)

    return u32(partial ^ shift_right_zf_by_u32(DEFAULT_PERMUTE_XOR_SHIFT, partial))


def update(state: State) -> State:
    return State(u32(state.value * DEFAULT_UPDATE_MULTIPLIER + state.increment), state.increment)


def draw_u32(state: State) -> tuple[int, State]:
    return permute(state), update(state)


def draw_i32(state: State) -> tuple[int, State]:
    value, next_state = draw_u32(state)
    return to_i32_wrap(value), next_state


def draw_u32_exclusive_range_unbiased(state: State, range_size: int) -> tuple[int, State]:
    threshold = U32_SIZE % range_size

    while True:
        candidate = permute(state)
        state = update(state)
        product = candidate * range_size
        low_bits = u32(product)

        if low_bits >= threshold:
            return u32(product >> 32), state


def draw_bounded_u32(state: State, x: int, y: int) -> tuple[int, State]:
    minimum, maximum = sorted((x, y))
    range_size = maximum - minimum + 1

    if range_size > MASK_U32:
        return draw_u32(state)

    offset, next_state = draw_u32_exclusive_range_unbiased(state, range_size)
    return minimum + offset, next_state


def draw_bounded_i32(state: State, x: int, y: int) -> tuple[int, State]:
    minimum, maximum = sorted((x, y))
    range_size = maximum - minimum + 1

    if range_size > MASK_U32:
        return draw_i32(state)

    offset, next_state = draw_u32_exclusive_range_unbiased(state, range_size)
    return to_i32_wrap(minimum + offset), next_state


def draw_list(seed: int, increment: int, count: int, draw: Callable[[State], tuple[int, State]]) -> list[int]:
    state = State(u32(seed), u32(increment))
    values = []

    for _ in range(count):
        value, state = draw(state)
        values.append(value)

    return values


def expected_values(case: Case) -> list[int]:
    match case.mode:
        case "u32":
            return draw_list(case.seed, case.increment, case.count, draw_u32)
        case "i32":
            return draw_list(case.seed, case.increment, case.count, draw_i32)
        case "bounded_u32":
            assert case.low is not None and case.high is not None
            return draw_list(
                case.seed,
                case.increment,
                case.count,
                lambda state: draw_bounded_u32(state, case.low, case.high),
            )
        case "bounded_i32":
            assert case.low is not None and case.high is not None
            return draw_list(
                case.seed,
                case.increment,
                case.count,
                lambda state: draw_bounded_i32(state, case.low, case.high),
            )
        case _:
            raise ValueError(f"unknown mode: {case.mode}")


PROBE_SOURCE = f"""app [main!] {{
\tpf: platform "{PLATFORM_URL}",
\trand: "__PACKAGE_DEPENDENCY__",
}}

import pf.Stdin
import pf.Stdout
import rand.Random

main! : List(Str) => Try({{}}, [Exit(I32)])
main! = |_args| {{
\tvar $continue = True

\twhile $continue {{
\t\tline = Stdin.line!()

\t\tif line == "" {{
\t\t\t$continue = False
\t\t}} else {{
\t\t\tprocess_line!(line)?
\t\t}}
\t}}

\tOk({{}})
}}

process_line! : Str => Try({{}}, [Exit(I32)])
process_line! = |line| {{
\tfields = line.split_on(" ")
\tmode = arg_at(fields, 0)?

\tif mode == "u32" {{
\t\trun_u32!(fields)
\t}} else if mode == "i32" {{
\t\trun_i32!(fields)
\t}} else if mode == "bounded_u32" {{
\t\trun_bounded_u32!(fields)
\t}} else if mode == "bounded_i32" {{
\t\trun_bounded_i32!(fields)
\t}} else {{
\t\tErr(Exit(1))
\t}}
}}

arg_at : List(Str), U64 -> Try(Str, [Exit(I32)])
arg_at = |args, index|
\tmatch args.get(index) {{
\t\tOk(value) => Ok(value)
\t\tErr(_) => Err(Exit(1))
\t}}

parse_u32_arg : List(Str), U64 -> Try(U32, [Exit(I32)])
parse_u32_arg = |args, index| {{
\traw = arg_at(args, index)?
\tmatch U32.from_str(raw) {{
\t\tOk(value) => Ok(value)
\t\tErr(_) => Err(Exit(1))
\t}}
}}

parse_i32_arg : List(Str), U64 -> Try(I32, [Exit(I32)])
parse_i32_arg = |args, index| {{
\traw = arg_at(args, index)?
\tmatch I32.from_str(raw) {{
\t\tOk(value) => Ok(value)
\t\tErr(_) => Err(Exit(1))
\t}}
}}

parse_u64_arg : List(Str), U64 -> Try(U64, [Exit(I32)])
parse_u64_arg = |args, index| {{
\traw = arg_at(args, index)?
\tmatch U64.from_str(raw) {{
\t\tOk(value) => Ok(value)
\t\tErr(_) => Err(Exit(1))
\t}}
}}

seed_arg : List(Str) -> Try(Random.State, [Exit(I32)])
seed_arg = |args| {{
\tseed = parse_u32_arg(args, 1)?
\tincrement = parse_u32_arg(args, 2)?
\tOk(Random.seed_variant(seed, increment))
}}

run_u32! : List(Str) => Try({{}}, [Exit(I32)])
run_u32! = |args| {{
\tstate = seed_arg(args)?
\tcount = parse_u64_arg(args, 3)?
\tvalues = Random.step(state, Random.list(Random.u32, count)).value

\tStdout.line!(Str.inspect(values))
\tOk({{}})
}}

run_i32! : List(Str) => Try({{}}, [Exit(I32)])
run_i32! = |args| {{
\tstate = seed_arg(args)?
\tcount = parse_u64_arg(args, 3)?
\tvalues = Random.step(state, Random.list(Random.i32, count)).value

\tStdout.line!(Str.inspect(values))
\tOk({{}})
}}

run_bounded_u32! : List(Str) => Try({{}}, [Exit(I32)])
run_bounded_u32! = |args| {{
\tstate = seed_arg(args)?
\tcount = parse_u64_arg(args, 3)?
\tlow = parse_u32_arg(args, 4)?
\thigh = parse_u32_arg(args, 5)?
\tvalues = Random.step(state, Random.list(Random.bounded_u32(low, high), count)).value

\tStdout.line!(Str.inspect(values))
\tOk({{}})
}}

run_bounded_i32! : List(Str) => Try({{}}, [Exit(I32)])
run_bounded_i32! = |args| {{
\tstate = seed_arg(args)?
\tcount = parse_u64_arg(args, 3)?
\tlow = parse_i32_arg(args, 4)?
\thigh = parse_i32_arg(args, 5)?
\tvalues = Random.step(state, Random.list(Random.bounded_i32(low, high), count)).value

\tStdout.line!(Str.inspect(values))
\tOk({{}})
}}
"""


def run(cmd: list[str], *, cwd: Path = ROOT, verbose: bool = True) -> subprocess.CompletedProcess[str]:
    if verbose:
        print("+", " ".join(cmd))
    completed = subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    if completed.returncode != 0:
        if completed.stdout:
            print(completed.stdout)
        if completed.stderr:
            print(completed.stderr, file=sys.stderr)
        raise SystemExit(f"command failed with exit code {completed.returncode}: {' '.join(cmd)}")

    return completed


def probe_source(package_dependency: str) -> str:
    return PROBE_SOURCE.replace("__PACKAGE_DEPENDENCY__", package_dependency)


def build_probe(tmp_dir: Path) -> Path:
    source = tmp_dir / "random_oracle_probe.roc"
    executable = tmp_dir / "random_oracle_probe"
    package_dependency = os.path.relpath(ROOT / "package" / "main.roc", source.parent).replace(os.sep, "/")

    source.write_text(probe_source(package_dependency), encoding="utf-8")
    run([ROC, "build", str(source), "--opt=speed", f"--output={executable}", "--no-cache"])

    return executable


def case_line(case: Case) -> str:
    fields = [case.mode, str(case.seed), str(case.increment), str(case.count)]
    if case.low is not None and case.high is not None:
        fields.extend([str(case.low), str(case.high)])

    return " ".join(fields)


def actual_values_by_case(executable: Path, cases: list[Case]) -> dict[str, list[int]]:
    stdin = "\n".join(case_line(case) for case in cases) + "\n"
    completed = subprocess.run(
        [str(executable)],
        cwd=ROOT,
        input=stdin,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    if completed.returncode != 0:
        if completed.stdout:
            print(completed.stdout)
        if completed.stderr:
            print(completed.stderr, file=sys.stderr)
        raise SystemExit(f"oracle probe failed with exit code {completed.returncode}")

    output_lines = completed.stdout.splitlines()
    if len(output_lines) != len(cases):
        raise SystemExit(f"oracle probe returned {len(output_lines)} lines for {len(cases)} cases")

    actual: dict[str, list[int]] = {}
    for case, output in zip(cases, output_lines, strict=True):
        actual[case.name] = parse_output(case, output)

    return actual


def parse_output(case: Case, output: str) -> list[int]:
    output = output.strip()

    try:
        parsed = ast.literal_eval(output)
    except (SyntaxError, ValueError) as err:
        raise SystemExit(f"{case.name}: could not parse Roc output {output!r}: {err}") from err

    if not isinstance(parsed, list) or not all(isinstance(value, int) for value in parsed):
        raise SystemExit(f"{case.name}: Roc output was not a list of ints: {output!r}")

    return parsed


def curated_cases() -> list[Case]:
    seeds = [0, 1, 2, 3, 6, 123, 1_234, 65_535, 2_147_483_648, MASK_U32]
    increments = [1, 3, DEFAULT_UPDATE_INCREMENT, MASK_U32]
    cases: list[Case] = []

    for seed in seeds:
        cases.append(Case(f"u32_seed_{seed}", "u32", seed, DEFAULT_UPDATE_INCREMENT, 24))
        cases.append(Case(f"i32_seed_{seed}", "i32", seed, DEFAULT_UPDATE_INCREMENT, 24))

    for increment in increments:
        cases.append(Case(f"u32_variant_{increment}", "u32", 1_234, increment, 24))

    for seed, low, high in [
        (0, 42, 42),
        (0, 0, 1),
        (1, 0, 250),
        (2, 250, 0),
        (3, 25, 75),
        (6, 0, (1 << 16) - 1),
        (7, 0, 2_147_483_648),
        (8, 0, 2_147_483_649),
        (9, 10, MASK_U32 - 1),
        (10, 0, MASK_U32 - 1),
        (11, 0, MASK_U32),
        (12, MASK_U32, 0),
    ]:
        cases.append(Case(f"bounded_u32_{seed}_{low}_{high}", "bounded_u32", seed, DEFAULT_UPDATE_INCREMENT, 24, low, high))

    for seed, low, high in [
        (0, -7, -7),
        (1, -10, 10),
        (2, 10, 9),
        (3, I32_LOWEST, I32_LOWEST + 9),
        (4, I32_HIGHEST - 9, I32_HIGHEST),
        (5, I32_LOWEST, I32_HIGHEST - 1),
        (6, I32_LOWEST + 1, I32_HIGHEST),
        (7, I32_LOWEST, I32_HIGHEST),
        (8, I32_HIGHEST, I32_LOWEST),
    ]:
        cases.append(Case(f"bounded_i32_{seed}_{low}_{high}", "bounded_i32", seed, DEFAULT_UPDATE_INCREMENT, 24, low, high))

    return cases


def randomized_cases() -> list[Case]:
    count = int(os.environ.get("ROC_RANDOM_ORACLE_RANDOM_CASES", "2000"))
    seed = int(os.environ.get("ROC_RANDOM_ORACLE_SEED", "20260711"))
    rng = random.Random(seed)
    cases: list[Case] = []

    for index in range(count // 2):
        seed = rng.randrange(U32_SIZE)
        increment = rng.randrange(U32_SIZE)
        draw_count = rng.randrange(1, 65)
        low = rng.randrange(U32_SIZE)
        high = rng.randrange(U32_SIZE)
        cases.append(Case(f"random_bounded_u32_{index}", "bounded_u32", seed, increment, draw_count, low, high))

    for index in range(count - (count // 2)):
        seed = rng.randrange(U32_SIZE)
        increment = rng.randrange(U32_SIZE)
        draw_count = rng.randrange(1, 65)
        low = rng.randrange(I32_LOWEST, I32_HIGHEST + 1)
        high = rng.randrange(I32_LOWEST, I32_HIGHEST + 1)
        cases.append(Case(f"random_bounded_i32_{index}", "bounded_i32", seed, increment, draw_count, low, high))

    return cases


def check_case(case: Case, actual: list[int]) -> None:
    expected = expected_values(case)

    if actual != expected:
        print(f"{case.name}: mismatch", file=sys.stderr)
        print(f"  command: {case_line(case)}", file=sys.stderr)
        print(f"  bounds: {case.low}, {case.high}", file=sys.stderr)
        print(f"  expected: {expected}", file=sys.stderr)
        print(f"  actual:   {actual}", file=sys.stderr)
        raise SystemExit(1)


def main() -> None:
    default_tmp = ROOT / ".roc-random-tmp"
    tmp_parent = Path(os.environ.get("ROC_RANDOM_TMPDIR", default_tmp))
    tmp_parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="roc-random-oracle-", dir=tmp_parent) as tmp:
        started = time.perf_counter()
        executable = build_probe(Path(tmp))
        built = time.perf_counter()
        cases = curated_cases() + randomized_cases()
        actual = actual_values_by_case(executable, cases)
        ran_probe = time.perf_counter()

        for case in cases:
            check_case(case, actual[case.name])

        finished = time.perf_counter()
        print(
            f"Python oracle matched optimized Roc probe for {len(cases)} cases "
            f"(build {built - started:.2f}s, probe {ran_probe - built:.2f}s, compare {finished - ran_probe:.2f}s)."
        )


if __name__ == "__main__":
    main()
