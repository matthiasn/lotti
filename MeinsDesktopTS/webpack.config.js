const path = require('path')

// webpack.config.js
module.exports = [
  {
    mode: 'development',
    entry: './src/main/index.ts',
    target: 'electron-main',
    resolve: {
      extensions: ['.ts', '.tsx', '.js', '.json'],
      modules: [
        path.join(__dirname, './node_modules'),
      ],
    },
    module: {
      rules: [{
        test: /\.ts$/,
        include: /src/,
        use: [{ loader: 'ts-loader' }]
      }]
    },
    output: {
      path: __dirname + '/out',
      filename: 'main.js'
    },
    externals: {
      sqlite3: 'commonjs sqlite3',
      'mongodb': {},
      'mssql': {},
      'mysql': {},
      'mysql2': {},
      'pg': {},
      'pg-native': {},
      'redis': {},
      'hiredis': {},
      '@sap/hdbext': {},
      'mongodb-client-encryption': {},
      'typeorm-aurora-data-api-driver': {},
      'ioredis': {},
      'sql.js': {},
      'aws-sdk': {},
      'react-native-sqlite-storage': {},
      'pg-query-stream': {},
      'oracledb': {},
    },
  }
];
