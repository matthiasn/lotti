import { Alert } from 'react-native';
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

export function readSteps(that) {
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
