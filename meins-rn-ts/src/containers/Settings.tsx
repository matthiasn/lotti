import React, {memo} from 'react';
import {useTranslation} from 'react-i18next';
import {Button, StyleSheet, Text, View} from 'react-native';
import Colors from 'src/constants/colors';

function Settings() {
  const {t, i18n} = useTranslation();
  return (
    <View style={styles.container}>
      <Text>{t('settings')}</Text>
      <Button title={t('english')} onPress={() => i18n.changeLanguage('en')} />
      <Button title={t('french')} onPress={() => i18n.changeLanguage('fr')} />
    </View>
  );
}

export default memo(Settings);

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: Colors.aliceBlue,
  },
});
