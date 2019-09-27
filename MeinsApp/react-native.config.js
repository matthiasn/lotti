// react-native.config.js
module.exports = {
    assets: [
        'react-native-vector-icons',
        './assets/fonts'
    ],
    dependencies: {
        '@matthiasn/react-native-mailcore': {
            platforms: {
                ios: null,
                android: null,
            },
        },
        '@matthiasn/rn-apple-healthkit': {
            platforms: {
                ios: null,
                android: null,
            },
        },
        'realm': {
            platforms: {
                ios: null,
                android: null,
            },
        },
    },
};