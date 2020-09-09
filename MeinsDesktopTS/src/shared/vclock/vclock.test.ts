import {VClock} from './index'

describe('Vector clock implementation', () => {

  test('generates Firebase token for random id', async () => {
    const vc0 = <VClock>{
      hostId: "foo",
      seq: 0,
    }

    const vc1 = <VClock>{
      hostId: "foo",
      seq: 1,
    }

    expect(vc0).not.toEqual(vc1)
  })
})
