import React, {memo} from 'react';
import {useTranslation} from 'react-i18next';
import {Platform, StyleSheet, Text, View} from 'react-native';
import Colors from 'src/constants/colors';
import {AudioRecorder} from 'src/components/AudioRecorder';

function Home() {
  const {t} = useTranslation();

  const instructions = Platform.select({
    ios: t('iosInstruction'),
    android: t('androidInstruction'),
  });

  return (
    <View style={styles.container}>
      <Text style={styles.welcome}>{t('welcome')}</Text>
      <Text style={styles.instructions}>{t('instructions')}</Text>
      <Text style={styles.instructions}>{instructions}</Text>
      <AudioRecorder />
    </View>
  );
}

export default memo(Home);

const styles = StyleSheet.create({
  container: {
    paddingTop: 50,
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: Colors.aliceBlue,
  },
  welcome: {
    fontSize: 20,
    textAlign: 'center',
    margin: 10,
  },
  instructions: {
    textAlign: 'center',
    color: Colors.darkCharcoal,
    marginBottom: 5,
  },
});
