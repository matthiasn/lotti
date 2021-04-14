import {render} from '@testing-library/react-native';
import React from 'react';
import 'react-native';
import {Provider} from 'react-redux';
import Home from 'src/containers/Home';
import {store} from 'src/store';

describe('Home', () => {
  jest.useFakeTimers();
  const pageTree = (
    <Provider store={store}>
      <Home />
    </Provider>
  );
  it('should renders correctly', () => {
    const page = render(pageTree);
    expect(page.toJSON()).toMatchSnapshot();
  });
});
