var path = require('path');

module.exports = {
    entry: './src/js/index.js',
    output: {
        filename: 'index_bundle.js',
        path: path.resolve(__dirname, 'resources/public')
    },
    node: {
        child_process: 'empty',
        fs: 'empty',
        module: 'empty',
        net: 'empty',
        tls: 'empty'
    },
    module: {
        rules: [
            {
                test: /\.css$/,
                use: [
                    {loader: 'style-loader'},
                    {loader: 'css-loader'}
                ]
            }
        ]
    }
};
