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
        hostId: "foo",
        seq: 0,
      },
      <VClockNode>{
        hostId: "bar",
        seq: 0,
      },
    ]

    const res = compareVClocks(vc0, vc0)
    expect(res).toEqual(VClockStatus.EQUAL)
  })

  test('return EQUAL when both clocks are the same but in different order', () => {
    const vc0: VClock = [
      <VClockNode>{
        hostId: "foo",
        seq: 0,
      },
      <VClockNode>{
        hostId: "bar",
        seq: 0,
      },
    ]

    const vc1: VClock = [
      <VClockNode>{
        hostId: "bar",
        seq: 0,
      },
      <VClockNode>{
        hostId: "foo",
        seq: 0,
      },
    ]

    const res = compareVClocks(vc0, vc1)
    expect(res).toEqual(VClockStatus.EQUAL)
  })
})

