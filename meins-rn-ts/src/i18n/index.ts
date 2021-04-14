import i18n from 'i18next';
import {initReactI18next} from 'react-i18next';

// tips: export each translation to a seperate file
const resources = {
  en: {
    translation: {
      english: 'English',
      french: 'Français',
      welcome: 'Welcome to Typescript React Native Starter!',
      instructions: 'To get started, edit Home.tsx',
      iosInstruction: 'Press Cmd+R to reload,\n' + 'Cmd+D or shake for dev menu',
      androidInstruction:
        'Double tap R on your keyboard to reload,\n' + 'Shake or press menu button for dev menu',
      settings: 'Settings',
      home: 'Home',
      fetchUser: 'Fetch user',
    },
  },
  fr: {
    translation: {
      welcome: 'Bienvenue à Typescript React Native Starter !',
      instructions: 'Pour commencer, éditez Home.tsx',
      iosInstruction: 'Appuyez sur Cmd+R pour recharger,\n' + 'Cmd+D ou secouez pour le menu dev',
      androidInstruction:
        'Appuyez deux fois sur la touche R de votre clavier pour recharger,\n' +
        'Secouer ou appuyer sur le bouton de menu pour le menu de développement',
      settings: 'Paramètres',
      home: 'Accueil',
    },
  },
};

i18n
  .use(initReactI18next) // passes i18n down to react-i18next
  .init({
    resources,
    lng: 'en',
    fallbackLng: 'en',

    keySeparator: false, // we do not use keys in form messages.welcome

    interpolation: {
      escapeValue: false, // react already safes from xss
    },
  });

export default i18n;
