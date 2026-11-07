# Simple Math Calculator — Assembly

A reverse Polish notation (RPN) calculator written in LC-3 assembly language. Type numbers onto a stack, then type an operator to do the math - no parentheses, no equals key.

## What it does

- Adds, subtracts, multiplies, and divides 16-bit signed integers
- Accepts multi-digit numbers (up to 4 digits)
- Displays the top of the stack with `.`
- Catches bad input, empty-stack use, division by zero, and overflow — and tells you which one happened

## Get Started

You need an LC-3 assembler and simulator. If you don't have one yet, follow the [LC-3 installation guide](https://github.com/gt-cs2110/lc3tools/blob/master/docs/INSTALL.md) (lc3tools).

```bash
# 1. Assemble the program (creates RPNSMC.obj)
lc3as RPNSMC.asm

# 2. Run it in the simulator
lc3sim RPNSMC.obj
```

That's it — the whole program is the single file `RPNSMC.asm`. No other dependencies.

## Example session

```
SMC RPN Calculator
Enter 0-9 or +, -, *, /
'.' to display result on TOS

> 15 7 +
> .
22
>
```

How that worked: `15` and `7` were pushed onto the stack (Space or Enter pushes a number), `+` popped both, added them, and pushed `22` back. `.` printed the top of the stack without removing it, so you can press `.` again and see `22` a second time.

More examples:

| You type | Result |
| -------- | ------ |
| `3 4 * .` | `12` |
| `10 3 - .` | `7` |
| `20 4 / .` | `5` |
| `2 3 + 4 * .` | `20` — `(2 + 3) * 4`, no parentheses needed |

## Usage

| Key | What it does |
| --- | ----------- |
| `0`–`9` | Build a number (up to 4 digits) |
| `Space` or `Enter` | Push the number you just typed onto the stack |
| `+` | Pop the top two numbers, push their sum |
| `-` | Pop the top two numbers, push left minus right |
| `*` | Pop the top two numbers, push their product |
| `/` | Pop the top two numbers, push the integer quotient |
| `.` | Print the top of the stack (does not remove it) |

Operators work on the top two stack values. For `-` and `/`, the number pushed first is the left operand: `10 3 -` is `10 - 3`, not `3 - 10`. Anything that isn't a digit, an operator, Space, or Enter is ignored.

## How the code works

The program is one file, `RPNSMC.asm`, starting at `x3000`. Everything runs off a stack that lives at `x4000` and grows downward — the stack pointer is `R4`.

**Main loop (`START`, `PROMPT_LOOP`, `READ_LOOP`)** — Sets `R4` to `x4000`, prints the title, then loops: print a `>` prompt and read one keystroke at a time with `GETC` (echoed back with `OUT`).

**Reading numbers** — Digits are accumulated in `R5`, with `R6` counting how many were typed. LC-3 has no multiply instruction, so multiplying the accumulator by 10 is done with addition: `x * 10 = (x * 8) + (x * 2)`. Each ASCII digit is converted to its value by subtracting `'0'`. A 5th digit is an error.

**Recognizing input** — LC-3 has no subtract or compare instruction, so the program stores the *negative* ASCII value of each key it cares about (`NEG_ZERO`, `NEG_PLUS`, …) and adds it to the typed character: a zero result means a match. That is how it tells digits, operators, Space, and Enter apart.

**The operators (`EXEC_ADD`, `EXEC_SUB`, `EXEC_MUL`, `EXEC_DIV`)** — Each pops the right operand first, then the left, computes, and pushes the result back:

- `+` and `-` use plain addition (`-` negates the right operand first with `NOT` + `1`, i.e. two's complement) and check for signed overflow: two positives adding to a negative, or two negatives adding to a positive.
- `*` tracks the signs in `R3`, makes both operands positive, and multiplies by repeated addition, checking for overflow if the running sum goes negative.
- `/` rejects a zero divisor, tracks signs the same way, and divides by repeated subtraction. The result is the integer quotient — the remainder is discarded.

**The stack (`PUSH_RPN`, `POP_RPN`)** — Push moves the pointer down one address and stores; pop loads and moves it back up. `POP_RPN` saves and restores `R1`/`R2` so a pop can't clobber a half-finished calculation, and errors out if the stack is empty.

**Printing (`PRINT_NUM`)** — Handles `0` as a special case, prints `-` for negatives, then pulls the digits out one at a time by repeatedly dividing by 10 (repeated subtraction for the remainder), stashing them on a second small stack at `x4100` so they come out in the right order, and converting each back to ASCII by adding `x30`.

**Errors** — Three messages, and every one resets the program back to the start (clearing the stack):

| Message | Meaning |
| ------- | ------- |
| `?- error occurred, input doesn't make sense` | Bad input, a 5th digit, or division by zero |
| `$stack error occurred` | Tried to use an empty stack |
| `!- numeric overflow or underflow` | A result didn't fit in 16 bits |

**Data pools** — The constants sit in two pools near the code because LC-3 loads can only reach 9 bits away: negative ASCII values for input checks, the stack base `x4000`, the print stack `x4100`, and the error strings.

## Limitations

- Integers only, 16-bit signed: −32,768 to 32,767.
- Numbers are at most 4 digits when typed in.
- Division is integer division — `7 2 /` gives `3`, not `3.5`.
- `.` is the display key, not a decimal point — there are no fractions here.
- You can't type a negative number directly; negatives come from subtraction or multiplication results.
- Any error resets the whole calculator, including the stack.
