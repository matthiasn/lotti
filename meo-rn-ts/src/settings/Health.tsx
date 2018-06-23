import React from 'react';
import { Text, View, ScrollView, StatusBar, Alert, Button } from 'react-native';
import AppleHealthKit from 'rn-apple-healthkit';
import RNFS from 'react-native-fs';

let healthOptions = {
  permissions: {
    read: [
      "Height", "Weight", "StepCount",
      "FlightsClimbed",
      "BloodPressureDiastolic", "BloodPressureSystolic", "HeartRate",
      "DistanceWalkingRunning", "SleepAnalysis", "RespiratoryRate",
      "DateOfBirth", "BodyMassIndex", "ActiveEnergyBurned"]
  }
};

interface HealthKitResult {
  value: number
}

function readSteps(that) {
  AppleHealthKit.initHealthKit(healthOptions, (err: string, results: Object) => {
    if (err) {
      console.log("error initializing HealthKit: ", err);
      Alert.alert(err)
      return;
    }

    AppleHealthKit.getStepCount({ date: (new Date()).toISOString() },
      (err: Object, results: HealthKitResult) => {
        console.log(results)
        if (err) {
          return;
        }
        const steps = results.value
        that.setState(prevState => {
          prevState.stepsToday = steps
          return prevState
        });
        console.log("steps today", steps)
      });

    let options = {
      startDate: (new Date(2016, 0, 1)).toISOString(), // required
      endDate: (new Date()).toISOString() // optional; default now
    };
    AppleHealthKit.getDailyStepCountSamples(options, (err: Object, results: Array<Object>) => {
      if (err) {
        console.error(err)
        return;
      }
      that.setState(prevState => {
        prevState.steps = results
        return prevState
      });
      const serialized = JSON.stringify(results)
      const path = RNFS.DocumentDirectoryPath + '/steps.json';

      RNFS.writeFile(path, serialized, 'utf8')
        .then((success) => {
          console.log('FILE WRITTEN!');
        })
        .catch((err) => {
          console.log(err.message);
        });
    });
  });
}

export default class HealthModal extends React.Component {
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
    const status = (cnt > 10000) ?
      { text: "good job", color: "green" } :
      { text: "keep moving", color: "red"}

    return (
      <ScrollView style={{ marginTop: 100 }}>
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
          <Text style={{ fontSize: 30, marginBottom: 10 }}>
            {this.state.stepsToday} steps today
          </Text>
          <Text style={{ fontSize: 30, fontWeight: "bold",  marginBottom: 10, color: status.color }}>
            {status.text}
          </Text>
          <Button
            onPress={() => this.props.navigation.goBack()}
            title="Dismiss"
          />
        </View>
        <View style={{ marginLeft: 40, marginTop: 40 }}>
          {listItems}
        </View>
      </ScrollView>
    );
  }
}
