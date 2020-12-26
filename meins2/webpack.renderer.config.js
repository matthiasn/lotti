const rules = require('./webpack.rules')
const plugins = require('./webpack.plugins')

rules.push({
  test: /\.(woff|woff2|png)$/,
  use: {
    loader: 'url-loader',
  },
})

rules.push({
  test: /\.css$/i,
  use: [
    {
      loader: 'style-loader',
    },
    {
      loader: 'css-loader',
    },
  ],
})

rules.push({
  test: /\.s[ac]ss$/i,
  use: [
    {
      loader: 'style-loader',
    },
    {
      loader: 'css-loader',
    },
    {
      loader: 'sass-loader',
    },
  ],
})

module.exports = {
  module: {
    rules,
  },
  plugins: plugins,
  resolve: {
    extensions: ['.js', '.ts', '.jsx', '.tsx', '.css'],
  },
}
