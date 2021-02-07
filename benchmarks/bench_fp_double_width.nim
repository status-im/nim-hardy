# Constantine
# Copyright (c) 2018-2019    Status Research & Development GmbH
# Copyright (c) 2020-Present Mamy André-Ratsimbazafy
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at http://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at http://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

# ############################################################
#
#             Benchmark of finite fields
#
# ############################################################

import
  # Internals
  ../constantine/config/[curves, common],
  ../constantine/arithmetic,
  ../constantine/towers,
  # Helpers
  ../helpers/[prng_unsafe, static_for],
  ./platforms,
  # Standard library
  std/[monotimes, times, strformat, strutils, macros]

var rng: RngState
let seed = uint32(getTime().toUnix() and (1'i64 shl 32 - 1)) # unixTime mod 2^32
rng.seed(seed)
echo "bench xoshiro512** seed: ", seed

# warmup
proc warmup*() =
  # Warmup - make sure cpu is on max perf
  let start = cpuTime()
  var foo = 123
  for i in 0 ..< 300_000_000:
    foo += i*i mod 456
    foo = foo mod 789

  # Compiler shouldn't optimize away the results as cpuTime rely on sideeffects
  let stop = cpuTime()
  echo &"Warmup: {stop - start:>4.4f} s, result {foo} (displayed to avoid compiler optimizing warmup away)\n"

warmup()

when defined(gcc):
  echo "\nCompiled with GCC"
elif defined(clang):
  echo "\nCompiled with Clang"
elif defined(vcc):
  echo "\nCompiled with MSVC"
elif defined(icc):
  echo "\nCompiled with ICC"
else:
  echo "\nCompiled with an unknown compiler"

echo "Optimization level => "
echo "  no optimization: ", not defined(release)
echo "  release: ", defined(release)
echo "  danger: ", defined(danger)
echo "  inline assembly: ", UseASM_X86_64

when (sizeof(int) == 4) or defined(Constantine32):
  echo "⚠️ Warning: using Constantine with 32-bit limbs"
else:
  echo "Using Constantine with 64-bit limbs"

when SupportsCPUName:
  echo "Running on ", cpuName(), ""

when SupportsGetTicks:
  echo "\n⚠️ Cycles measurements are approximate and use the CPU nominal clock: Turbo-Boost and overclocking will skew them."
  echo "i.e. a 20% overclock will be about 20% off (assuming no dynamic frequency scaling)"

echo "\n=================================================================================================================\n"

proc separator*() =
  echo "-".repeat(145)

proc report(op, field: string, start, stop: MonoTime, startClk, stopClk: int64, iters: int) =
  let ns = inNanoseconds((stop-start) div iters)
  let throughput = 1e9 / float64(ns)
  when SupportsGetTicks:
    echo &"{op:<28} {field:<40} {throughput:>15.3f} ops/s     {ns:>9} ns/op     {(stopClk - startClk) div iters:>9} CPU cycles (approx)"
  else:
    echo &"{op:<28} {field:<40} {throughput:>15.3f} ops/s     {ns:>9} ns/op"

proc notes*() =
  echo "Notes:"
  echo "  - Compilers:"
  echo "    Compilers are severely limited on multiprecision arithmetic."
  echo "    Inline Assembly is used by default (nimble bench_fp)."
  echo "    Bench without assembly can use \"nimble bench_fp_gcc\" or \"nimble bench_fp_clang\"."
  echo "    GCC is significantly slower than Clang on multiprecision arithmetic due to catastrophic handling of carries."
  echo "  - The simplest operations might be optimized away by the compiler."
  echo "  - Fast Squaring and Fast Multiplication are possible if there are spare bits in the prime representation (i.e. the prime uses 254 bits out of 256 bits)"

template bench(op: string, desc: string, iters: int, body: untyped): untyped =
  let start = getMonotime()
  when SupportsGetTicks:
    let startClk = getTicks()
  for _ in 0 ..< iters:
    body
  when SupportsGetTicks:
    let stopClk = getTicks()
  let stop = getMonotime()

  when not SupportsGetTicks:
    let startClk = -1'i64
    let stopClk = -1'i64

  report(op, desc, start, stop, startClk, stopClk, iters)

func random_unsafe(rng: var RngState, a: var FpDbl, Base: typedesc) =
  ## Initialize a standalone Double-Width field element
  ## we don't reduce it modulo p², this is only used for benchmark
  let aHi = rng.random_unsafe(Base)
  let aLo = rng.random_unsafe(Base)
  for i in 0 ..< aLo.mres.limbs.len:
    a.limbs2x[i] = aLo.mres.limbs[i]
  for i in 0 ..< aHi.mres.limbs.len:
    a.limbs2x[aLo.mres.limbs.len+i] = aHi.mres.limbs[i]

proc sumUnred(T: typedesc, iters: int) =
  var r: T
  let a = rng.random_unsafe(T)
  let b = rng.random_unsafe(T)
  bench("Addition unreduced", $T, iters):
    r.sumUnred(a, b)

proc sum(T: typedesc, iters: int) =
  var r: T
  let a = rng.random_unsafe(T)
  let b = rng.random_unsafe(T)
  bench("Addition", $T, iters):
    r.sum(a, b)

proc diffUnred(T: typedesc, iters: int) =
  var r: T
  let a = rng.random_unsafe(T)
  let b = rng.random_unsafe(T)
  bench("Substraction unreduced", $T, iters):
    r.diffUnred(a, b)

proc diff(T: typedesc, iters: int) =
  var r: T
  let a = rng.random_unsafe(T)
  let b = rng.random_unsafe(T)
  bench("Substraction", $T, iters):
    r.diff(a, b)

proc diff2xNoReduce(T: typedesc, iters: int) =
  var r, a, b: doubleWidth(T)
  rng.random_unsafe(r, T)
  rng.random_unsafe(a, T)
  rng.random_unsafe(b, T)
  bench("Substraction 2x unreduced", $doubleWidth(T), iters):
    r.diff2xUnred(a, b)

proc diff2x(T: typedesc, iters: int) =
  var r, a, b: doubleWidth(T)
  rng.random_unsafe(r, T)
  rng.random_unsafe(a, T)
  rng.random_unsafe(b, T)
  bench("Substraction 2x reduced", $doubleWidth(T), iters):
    r.diff2xMod(a, b)

proc prod2xBench*(rLen, aLen, bLen: static int, iters: int) =
  var r: BigInt[rLen]
  let a = rng.random_unsafe(BigInt[aLen])
  let b = rng.random_unsafe(BigInt[bLen])
  bench("Multiplication 2x", $rLen & " <- " & $aLen & " x " & $bLen, iters):
    r.prod(a, b)

proc square2xBench*(rLen, aLen: static int, iters: int) =
  var r: BigInt[rLen]
  let a = rng.random_unsafe(BigInt[aLen])
  bench("Squaring 2x", $rLen & " <- " & $aLen & "²", iters):
    r.square(a)

proc reduce2x*(T: typedesc, iters: int) =
  var r: T
  var t: doubleWidth(T)
  rng.random_unsafe(t, T)

  bench("Redc 2x", $T & " <- " & $doubleWidth(T), iters):
    r.redc2x(t)

proc main() =
  separator()
  sumUnred(Fp[BLS12_381], iters = 10_000_000)
  diffUnred(Fp[BLS12_381], iters = 10_000_000)
  sum(Fp[BLS12_381], iters = 10_000_000)
  diff(Fp[BLS12_381], iters = 10_000_000)
  diff2x(Fp[BLS12_381], iters = 10_000_000)
  diff2xNoReduce(Fp[BLS12_381], iters = 10_000_000)
  prod2xBench(768, 384, 384, iters = 10_000_000)
  square2xBench(768, 384, iters = 10_000_000)
  reduce2x(Fp[BLS12_381], iters = 10_000_000)
  separator()

main()
notes()
