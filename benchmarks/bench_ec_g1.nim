# Constantine
# Copyright (c) 2018-2019    Status Research & Development GmbH
# Copyright (c) 2020-Present Mamy André-Ratsimbazafy
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at http://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at http://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import
  # Internals
  ../constantine/config/curves,
  ../constantine/arithmetic,
  ../constantine/elliptic/[
    ec_shortweierstrass_projective,
    ec_shortweierstrass_jacobian],
  # Helpers
  ../helpers/static_for,
  ./bench_elliptic_template,
  # Standard library
  std/strutils

# ############################################################
#
#               Benchmark of the G1 group of
#            Short Weierstrass elliptic curves
#          in (homogeneous) projective coordinates
#
# ############################################################


const Iters = 10_000
const MulIters = 100
const AvailableCurves = [
  # P224,
  BN254_Nogami,
  BN254_Snarks,
  # Curve25519,
  # P256,
  # Secp256k1,
  BLS12_377,
  BLS12_381,
]

proc main() =
  separator()
  staticFor i, 0, AvailableCurves.len:
    const curve = AvailableCurves[i]
    addBench(ECP_ShortW_Prj[Fp[curve], NotOnTwist], Iters)
    addBench(ECP_ShortW_Jac[Fp[curve], NotOnTwist], Iters)
    mixedAddBench(ECP_ShortW_Prj[Fp[curve], NotOnTwist], Iters)
    mixedAddBench(ECP_ShortW_Jac[Fp[curve], NotOnTwist], Iters)
    doublingBench(ECP_ShortW_Prj[Fp[curve], NotOnTwist], Iters)
    doublingBench(ECP_ShortW_Jac[Fp[curve], NotOnTwist], Iters)
    separator()
    affFromProjBench(ECP_ShortW_Prj[Fp[curve], NotOnTwist], MulIters)
    affFromJacBench(ECP_ShortW_Jac[Fp[curve], NotOnTwist], MulIters)
    separator()
    scalarMulUnsafeDoubleAddBench(ECP_ShortW_Prj[Fp[curve], NotOnTwist], MulIters)
    scalarMulUnsafeDoubleAddBench(ECP_ShortW_Jac[Fp[curve], NotOnTwist], MulIters)
    separator()
    scalarMulGenericBench(ECP_ShortW_Prj[Fp[curve], NotOnTwist], window = 2, MulIters)
    scalarMulGenericBench(ECP_ShortW_Prj[Fp[curve], NotOnTwist], window = 3, MulIters)
    scalarMulGenericBench(ECP_ShortW_Prj[Fp[curve], NotOnTwist], window = 4, MulIters)
    scalarMulGenericBench(ECP_ShortW_Prj[Fp[curve], NotOnTwist], window = 5, MulIters)
    scalarMulGenericBench(ECP_ShortW_Jac[Fp[curve], NotOnTwist], window = 2, MulIters)
    scalarMulGenericBench(ECP_ShortW_Jac[Fp[curve], NotOnTwist], window = 3, MulIters)
    scalarMulGenericBench(ECP_ShortW_Jac[Fp[curve], NotOnTwist], window = 4, MulIters)
    scalarMulGenericBench(ECP_ShortW_Jac[Fp[curve], NotOnTwist], window = 5, MulIters)
    separator()
    scalarMulEndo(ECP_ShortW_Prj[Fp[curve], NotOnTwist], MulIters)
    scalarMulEndoWindow(ECP_ShortW_Prj[Fp[curve], NotOnTwist], MulIters)
    scalarMulEndo(ECP_ShortW_Jac[Fp[curve], NotOnTwist], MulIters)
    scalarMulEndoWindow(ECP_ShortW_Jac[Fp[curve], NotOnTwist], MulIters)
    separator()
    separator()

main()
notes()
