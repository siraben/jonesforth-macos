# JonesForth for macOS AArch64

A port of Richard W.M. Jones's excellent [JonesForth](http://rwmj.wordpress.com/2010/08/07/jonesforth-git-repository/) to macOS on Apple Silicon (ARM64/AArch64).

JonesForth is a literate implementation of a FORTH compiler and tutorial, originally written for Linux/i386. The assembly source (`jonesforth.S`) is extensively commented and serves as a tutorial on how FORTH works at the lowest level. This port preserves the original's educational spirit while adapting it for modern Apple Silicon Macs.

## What changed from the original

- **Architecture**: x86 → AArch64 (ARM64). Registers, addressing modes, and instruction encoding are completely different.
- **Calling conventions**: macOS AArch64 syscall conventions (`svc #0x80`, syscall number in `x16`, `0x2000000` class offset).
- **Cell size**: 32-bit → 64-bit cells. The high-level FORTH (`jonesforth.f`) uses standard `CELL`, `CELL+`, `CELL-`, and `CELLS` words rather than hardcoded offsets, making the cell size easy to identify and change.
- **Position-independent code**: Uses `adrp`/`add` for all address references (required by macOS).
- **Dictionary in `.data` segment**: macOS does not allow relocations in `__TEXT`, so the linked-list dictionary lives in `.data`.
- **No `brk` syscall**: macOS does not support `brk`; memory management is simplified.
- **Alignment**: 8-byte aligned (was 4-byte).
- **Indirect threaded code**: Same ITC model as the original, with `x26` as instruction pointer, `x27` as return stack pointer, `x28` as data stack pointer.

## Building

### With a C compiler

```sh
cc -o jonesforth jonesforth.S
```

### With Nix

```sh
nix build
```

This produces `result/bin/jonesforth` and a `result/bin/jonesforth-repl` wrapper that loads `jonesforth.f` automatically.

## Running

The bare binary only has the assembly primitives. To get a usable FORTH with `IF`/`THEN`, `DO`/`LOOP`, `."`, `SEE`, etc., pipe `jonesforth.f` in first:

```sh
cat jonesforth.f - | ./jonesforth
```

Or with the Nix wrapper:

```sh
./result/bin/jonesforth-repl
```

You should see:

```
JONESFORTH VERSION 47
131039 CELLS REMAINING
```

Try it out:

```forth
: FACTORIAL ( n -- n! ) DUP 1 > IF DUP 1- RECURSE * ELSE DROP 1 THEN ;
10 FACTORIAL .
3628800  OK
```

## Reading the source

The source code is the tutorial. Start with `jonesforth.S` — it's written as a literate program with extensive comments explaining every aspect of how FORTH works, from the threading model to the dictionary structure to how words are compiled. Then read `jonesforth.f` which builds the rest of the language in FORTH itself.

Set your tab width to 8 for correct formatting.

## Files

| File | Description |
|------|-------------|
| `jonesforth.S` | AArch64 assembly — the FORTH kernel and tutorial |
| `jonesforth.f` | High-level FORTH — builds the rest of the language |
| `flake.nix` | Nix flake for reproducible builds |

## License

Public domain, following the original JonesForth. See the comment at the top of `jonesforth.S`.

## Acknowledgements

- [Richard W.M. Jones](http://annexia.org/forth) for the original JonesForth
- [nornagon](https://github.com/nornagon/jonesforth) for maintaining a mirror of the original
- LINA FORTH by Albert van der Horst, which influenced the original design
