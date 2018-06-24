import React, { Component } from 'react';
import { Text, View, ScrollView, StatusBar, Button } from 'react-native';
import { readSteps } from '../health/HealthKit'

interface Props {
  navigation: {
    addListener: Function,
    navigate: Function,
    goBack: Function
  };
}

interface State {
  stepsToday: number;
  steps: Array<any>;
}

export default class HealthModal extends Component<Props, State> {
  state = {
    stepsToday: 0,
    steps: []
  }

  componentDidMount() {
    readSteps(this)
    this.props.navigation.addListener('didFocus', () => {
      StatusBar.setBarStyle('dark-content');
    });
  }

  render() {
    const listItems = this.state.steps.map(({ value, startDate }) =>
      <Text style={{ fontFamily: "Courier", fontSize: 22 }} key={startDate}> {startDate.substring(0, 10)}:
        &nbsp;&nbsp;&nbsp;
      <Text style={{ fontWeight: "bold" }}>{parseInt(value)}</Text></Text>);
    const cnt = this.state.stepsToday
    const status = (cnt > 7500) ?
      { text: "good job", color: "green" } :
      { text: "keep moving", color: "red" }

    return (
      <ScrollView style={{ marginTop: 100 }}>
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
          <Text style={{ fontSize: 30, marginBottom: 10 }}>
            {this.state.stepsToday} steps today
          </Text>
          <Text style={{ fontSize: 30, fontWeight: "bold", marginBottom: 10, color: status.color }}>
            {status.text}
          </Text>
          <Button
            onPress={() => this.props.navigation.goBack()}
            title="back"
          />
        </View>
        <View style={{ marginLeft: 40, marginTop: 40 }}>
          {listItems}
        </View>
      </ScrollView>
    );
  }
}
