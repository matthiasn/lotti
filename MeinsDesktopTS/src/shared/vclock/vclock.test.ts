import {compareVClocks, VClock, VClockNode, VClockStatus} from './index'

describe('Vector clock comparison function', () => {
  test('returns EQUAL when both clocks are the same & empty', () => {
    const vc0: VClock = []
    const res = compareVClocks(vc0, vc0)
    expect(res).toEqual(VClockStatus.EQUAL)
  })

  test('returns EQUAL when both clocks are the same', () => {
    const vc0: VClock = [
      <VClockNode>{
        nodeId: 'foo',
        seq: 0,
      },
      <VClockNode>{
        nodeId: 'bar',
        seq: 0,
      },
    ]

    const res = compareVClocks(vc0, vc0)
    expect(res).toEqual(VClockStatus.EQUAL)
  })

  test('return EQUAL when both clocks are the same but in different order', () => {
    const vc0: VClock = [
      <VClockNode>{
        nodeId: 'foo',
        seq: 0,
      },
      <VClockNode>{
        nodeId: 'bar',
        seq: 0,
      },
    ]

    const vc1: VClock = [
      <VClockNode>{
        nodeId: 'bar',
        seq: 0,
      },
      <VClockNode>{
        nodeId: 'foo',
        seq: 0,
      },
    ]

    const res = compareVClocks(vc0, vc1)
    expect(res).toEqual(VClockStatus.EQUAL)
  })

  test('returns A_GT_B when A dominates B', () => {
    const vc0: VClock = [
      <VClockNode>{
        nodeId: 'foo',
        seq: 2,
      },
      <VClockNode>{
        nodeId: 'bar',
        seq: 1,
      },
    ]

    const vc1: VClock = [
      <VClockNode>{
        nodeId: 'foo',
        seq: 1,
      },
      <VClockNode>{
        nodeId: 'bar',
        seq: 1,
      },
    ]

    const res = compareVClocks(vc0, vc1)
    expect(res).toEqual(VClockStatus.A_GT_B)
  })

  test('returns A_GT_B when A dominates B and B empty', () => {
    const vc0: VClock = [
      <VClockNode>{
        nodeId: 'foo',
        seq: 2,
      },
      <VClockNode>{
        nodeId: 'bar',
        seq: 1,
      },
    ]

    const vc1: VClock = []
    const res = compareVClocks(vc0, vc1)
    expect(res).toEqual(VClockStatus.A_GT_B)
  })

  test('returns B_GT_A when B dominates A', () => {
    const vc0: VClock = [
      <VClockNode>{
        nodeId: 'foo',
        seq: 2,
      },
      <VClockNode>{
        nodeId: 'bar',
        seq: 1,
      },
    ]

    const vc1: VClock = [
      <VClockNode>{
        nodeId: 'foo',
        seq: 3,
      },
      <VClockNode>{
        nodeId: 'bar',
        seq: 2,
      },
    ]

    const res = compareVClocks(vc0, vc1)
    expect(res).toEqual(VClockStatus.B_GT_A)
  })

  test('returns B_GT_A when B dominates A via additional node', () => {
    const vc0: VClock = [
      <VClockNode>{
        nodeId: 'foo',
        seq: 2,
      },
      <VClockNode>{
        nodeId: 'bar',
        seq: 1,
      },
    ]

    const vc1: VClock = [
      <VClockNode>{
        nodeId: 'foo',
        seq: 2,
      },
      <VClockNode>{
        nodeId: 'bar',
        seq: 1,
      },
      <VClockNode>{
        nodeId: 'baz',
        seq: 2,
      },
    ]

    const res = compareVClocks(vc0, vc1)
    expect(res).toEqual(VClockStatus.B_GT_A)
  })

  test('returns CONCURRENT when there is a conflict', () => {
    const vc0: VClock = [
      <VClockNode>{
        nodeId: 'foo',
        seq: 1,
      },
      <VClockNode>{
        nodeId: 'bar',
        seq: 2,
      },
    ]

    const vc1: VClock = [
      <VClockNode>{
        nodeId: 'foo',
        seq: 2,
      },
      <VClockNode>{
        nodeId: 'bar',
        seq: 1,
      },
    ]

    const res = compareVClocks(vc0, vc1)
    expect(res).toEqual(VClockStatus.CONCURRENT)
  })
})
