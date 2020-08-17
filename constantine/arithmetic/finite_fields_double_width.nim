# Constantine
# Copyright (c) 2018-2019    Status Research & Development GmbH
# Copyright (c) 2020-Present Mamy André-Ratsimbazafy
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at http://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at http://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import
  ../config/[common, curves, type_bigint, type_fp],
  ../primitives,
  ./bigints,
  ./finite_fields,
  ./limbs,
  ./limbs_double_width

type FpDbl*[C: static Curve] = object
  ## Double-width Fp element
  ## This allows saving on reductions
  # We directly work with double the number of limbs
  limbs2x*: matchingLimbs2x(C)

template doubleWidth*(T: typedesc[Fp]): typedesc =
  ## Return the double-width type matching with Fp
  FpDbl[T.C]

func mulNoReduce*(r: var FpDbl, a, b: Fp) {.inline.} =
  ## Store the product of ``a`` by ``b`` into ``r``
  r.limbs2x.prod(a.mres.limbs, b.mres.limbs)

func reduce*(r: var Fp, a: FpDbl) {.inline.} =
  ## Reduce a double-width field element into r
  const N = r.mres.limbs.len
  montyRed(
    r.mres.limbs,
    a.limbs2x,
    Fp.C.Mod.limbs,
    Fp.C.getNegInvModWord(),
    Fp.C.canUseNoCarryMontyMul()
  )

func diffNoReduce*(r: var FpDbl, a, b: FpDbl) {.inline.} =
  ## Double-width substraction without reduction
  discard r.limbs2x.diff(a.limbs2x, b.limbs2x)

func diff*(r: var FpDbl, a, b: FpDbl) =
  ## Double-width modular

  var underflowed = SecretBool r.limbs2x.diff(a.limbs2x, b.limbs2x)

  const N = r.limbs2x.len div 2
  const M = FpDbl.C.Mod
  var carry = Carry(0)
  var sum: SecretWord
  for i in 0 ..< N:
    addC(carry, sum, r.limbs2x[i+N], M.limbs[i], carry)
    underflowed.ccopy(r.limbs2x[i+N], sum)