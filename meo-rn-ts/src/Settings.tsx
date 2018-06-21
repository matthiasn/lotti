import React from 'react';
import { Component } from 'react';
import {
  AppRegistry,
  StyleSheet,
  Text,
  View,
  Image,
  Alert
} from 'react-native';
import SettingsList from 'react-native-settings-list';
import Icon from 'react-native-vector-icons/FontAwesome';
import AppleHealthKit from 'rn-apple-healthkit';
var RNFS = require('react-native-fs');

const bg = "#141414";
const itemBg = "#272727";
const textColor = "#D8D8D8";

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
          prevState.steps = steps
          return prevState
        });
        console.log("steps today", steps)
      });

    let options = {
      startDate: (new Date(2017, 1, 1)).toISOString(), // required
      endDate: (new Date()).toISOString() // optional; default now
    };
    AppleHealthKit.getDailyStepCountSamples(options, (err: Object, results: Array<Object>) => {
      if (err) {
        console.error(err)
        return;
      }
      const serialized = JSON.stringify(results)
      const path = RNFS.DocumentDirectoryPath + '/steps.json';

      RNFS.writeFile(path, serialized, 'utf8')
        .then((success) => {
          console.log('FILE WRITTEN!');
          Alert.alert("steps written")
        })
        .catch((err) => {
          console.log(err.message);
        });
    });
  });
}

const settingsIcon = (name) => (
  <Icon name={name} size={20} style={{ paddingTop: 14, paddingLeft: 14 }} color={textColor} />
)

export default class Settings extends Component<any> {

  constructor(props: any) {
    super(props);
    this.onValueChange = this.onValueChange.bind(this);
    this.state = {
      switchValue: false,
      loggedIn: false,
      steps: 111,
      toggleAuthView: () => { }
    };
  }
  render() {
    return (
      <View style={{ backgroundColor: bg, flex: 1, width: "100%" }}>
        <View style={{ backgroundColor: bg }}>
          <Text style={{ alignSelf: 'center', marginTop: 40, marginBottom: 10, fontWeight: 'bold', color: "white", fontSize: 16 }}>meo</Text>
        </View>
        <View style={{ backgroundColor: bg, flex: 1 }}>
          <SettingsList borderColor={bg} defaultItemSize={50}>
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("moon-o")}
              hasSwitch={true}
              //switchState={this.state.switchValue}
              switchOnValueChange={this.onValueChange}
              hasNavArrow={false}
              title='Dark Theme'
            />
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("database")}
              title='Database'
              titleInfo='91345'
              titleInfoStyle={styles.titleInfoStyle}
              onPress={() => Alert.alert('Route to Database Page')}
            />
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("address-book")}
              title='Contacts'
              titleInfoStyle={styles.titleInfoStyle}
              onPress={() => Alert.alert('Route to Contacts Page')}
            />
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("heartbeat")}
              title='Health Data'
              titleInfo={this.state.steps.toString()}
              titleInfoStyle={styles.titleInfoStyle}
              onPress={() => readSteps(this)}
            />
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("font")}
              title='Style'
              titleInfoStyle={styles.titleInfoStyle}
              onPress={() => Alert.alert('Route to Style Page')}
            />
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("shield")}
              title='Security'
              onPress={() => Alert.alert('Route To Security Page')}
            />
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("eye")}
              title='Dev'
              titleInfoStyle={styles.titleInfoStyle}
              onPress={() => Alert.alert('Route To Dev Page')}
            />
            <SettingsList.Header headerStyle={{ marginTop: 15 }} />
            <SettingsList.Item
              backgroundColor={itemBg}
              titleStyle={styles.titleStyle}
              icon={settingsIcon("warning")}
              title='Notifications'
              onPress={() => Alert.alert('Route To Notifications Page')}
            />
          </SettingsList>
        </View>
      </View>
    );
  }
  toggleAuthView() {
    //this.setState({toggleAuthView: !this.state.toggleAuthView});
  }
  onValueChange(value) {
    this.setState({ switchValue: value });
  }
}

const styles = StyleSheet.create({
  imageStyle: {
    marginLeft: 15,
    alignSelf: 'center',
    height: 30,
    width: 30
  },
  titleInfoStyle: {
    fontSize: 12,
    color: '#8e8e93'
  },
  titleStyle: {
    color: textColor,
    fontSize: 16
  }
});
