import _ from 'lodash'

export type VClockNode = {
  hostId: string
  seq: number
}

export type VClock = Array<VClockNode>
export type VClockInternal = Map<string, number>

export enum VClockStatus {
  EQUAL,
  A_GT_B,
  B_GT_A,
  CONCURRENT
}

function vclockToObject(vc: VClock): VClockInternal {
  const res: VClockInternal = new Map()
  vc.forEach((vc) => res.set(vc.hostId, vc.seq))
  return res
}

export function compareVClocks(a: VClock, b: VClock) {
  const aInternal = vclockToObject(a)
  const bInternal = vclockToObject(b)

  if (_.isEqual(aInternal, bInternal)) {
    return VClockStatus.EQUAL
  }

  return false
}
