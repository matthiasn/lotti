import _ from 'lodash'

export type VClockNode = {
  nodeId: string
  seq: number
}

export type VClock = Array<VClockNode>
export type VClockInternal = Map<string, number>

export enum VClockStatus {
  EQUAL,
  A_GT_B,
  B_GT_A,
  CONCURRENT,
}

function vclockToObject(vc: VClock): VClockInternal {
  const res: VClockInternal = new Map()
  vc.forEach((vc) => res.set(vc.nodeId, vc.seq))
  return res
}

export function compareVClocks(a: VClock, b: VClock) {
  const aInternal = vclockToObject(a)
  const bInternal = vclockToObject(b)

  if (_.isEqual(aInternal, bInternal)) {
    return VClockStatus.EQUAL
  }

  const statuses = new Set<VClockStatus>()
  const nodeIds = new Set<string>([...aInternal.keys(), ...bInternal.keys()])

  nodeIds.forEach((nodeId) => {
    const seqA = aInternal.get(nodeId) || 0
    const seqB = bInternal.get(nodeId) || 0
    if (seqA > seqB) {
      statuses.add(VClockStatus.A_GT_B)
    }
    if (seqA < seqB) {
      statuses.add(VClockStatus.B_GT_A)
    }
  })

  if (statuses.size == 1) {
    return statuses.values().next().value
  }

  if (statuses.size > 1) {
    return VClockStatus.CONCURRENT
  }
}
