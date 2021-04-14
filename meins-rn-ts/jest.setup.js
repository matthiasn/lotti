import 'isomorphic-fetch';
import mockAsyncStorage from '@react-native-community/async-storage/jest/async-storage-mock';
import nock from 'nock';
import 'react-native-gesture-handler/jestSetup';

// for persistor compatibility
// jest.useFakeTimers();

jest.mock('@react-native-community/async-storage', () => mockAsyncStorage);

jest.mock('react-native-bootsplash', () => {
  return {
    hide: jest.fn(),
    show: jest.fn(),
  };
});

nock.disableNetConnect();

jest.mock('react-native-reanimated', () => {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const Reanimated = require('react-native-reanimated/mock');

  // The mock for `call` immediately calls the callback which is incorrect
  // So we override it with a no-op
  // eslint-disable-next-line @typescript-eslint/no-empty-function
  Reanimated.default.call = () => {};

  return Reanimated;
});

// Silence the warning: Animated: `useNativeDriver` is not supported because the native animated module is missing
jest.mock('react-native/Libraries/Animated/src/NativeAnimatedHelper');
