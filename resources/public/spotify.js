/**
 * This is an example of a basic node.js script that performs
 * the Authorization Code oAuth2 flow to authenticate against
 * the Spotify Accounts.
 *
 * For more information, read
 * https://developer.spotify.com/web-api/authorization-guide/#authorization_code_flow
 *
 * ADAPTED from https://github.com/spotify/web-api-auth-examples
 */

const express = require('express');
const request = require('request');
const querystring = require('querystring');
const cookieParser = require('cookie-parser');
const fs = require('fs');
const log = require('electron-log');
const tcpPortUsed = require('tcp-port-used');

const PORT = Number(process.env.SPOTIFY_PORT || 8888);
const appPath = process.env.APP_PATH;
const userData = process.env.USER_DATA;
const client_id = '30912a450a164a18b42ecdcba0097703'; // Your client id
const redirect_uri = 'http://localhost:8888/callback'; // Your redirect uri
let client_secret;
const win32 = process.platform === "win32";
const pid = process.pid;


log.transports.file.level = 'info';
log.transports.file.format = '{h}:{i}:{s}:{ms} {text}';

if (!win32) {
    log.transports.file.file = '/tmp/spotify.log';
}

console.log = function (d) {
    log.info("SPOTIFY:", d);
};

try {
    client_secret = fs.readFileSync(userData + "/SPOTIFY_SECRET", "utf8");
    log.info("SPOTIFY: client secret", client_secret)
} catch (err) {
    log.error("SPOTIFY: client secret", err)
}

/**
 * Generates a random string containing numbers and letters
 * @param  {number} length The length of the string
 * @return {string} The generated string
 */
const generateRandomString = function (length) {
    let text = '';
    const possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

    for (let i = 0; i < length; i++) {
        text += possible.charAt(Math.floor(Math.random() * possible.length));
    }
    return text;
};

const stateKey = 'spotify_auth_state';
const expressApp = express();

const htmlPath = appPath + "/electron/spotify";
log.info("SPOTIFY: static path", htmlPath);
expressApp.use(express.static(htmlPath)).use(cookieParser());

expressApp.get('/login', function (req, res) {

    const state = generateRandomString(16);
    res.cookie(stateKey, state);

    // your application requests authorization
    const scope = 'user-read-private user-read-email user-read-recently-played user-modify-playback-state';
    res.redirect('https://accounts.spotify.com/authorize?' +
        querystring.stringify({
            response_type: 'code',
            client_id: client_id,
            scope: scope,
            redirect_uri: redirect_uri,
            state: state
        }));
});

expressApp.get('/callback', function (req, res) {

    // your application requests refresh and access tokens
    // after checking the state parameter

    const code = req.query.code || null;
    const state = req.query.state || null;
    const storedState = req.cookies ? req.cookies[stateKey] : null;

    if (state === null || state !== storedState) {
        res.redirect('/#' +
            querystring.stringify({
                error: 'state_mismatch'
            }));
    } else {
        res.clearCookie(stateKey);
        const authOptions = {
            url: 'https://accounts.spotify.com/api/token',
            form: {
                code: code,
                redirect_uri: redirect_uri,
                grant_type: 'authorization_code'
            },
            headers: {
                'Authorization': 'Basic ' + (new Buffer(client_id + ':' + client_secret).toString('base64'))
            },
            json: true
        };

        request.post(authOptions, function (error, response, body) {
            if (!error && response.statusCode === 200) {

                const access_token = body.access_token,
                    refresh_token = body.refresh_token;

                const options = {
                    url: 'https://api.spotify.com/v1/me',
                    headers: {'Authorization': 'Bearer ' + access_token},
                    json: true
                };

                // use the access token to access the Spotify Web API
                request.get(options, function (error, response, body) {
                    log.info("SPOTIFY: POST", body);
                });

                // we can also pass the token to the browser to make requests from there
                res.redirect('/#' +
                    querystring.stringify({
                        access_token: access_token,
                        refresh_token: refresh_token
                    }));
            } else {
                res.redirect('/#' +
                    querystring.stringify({
                        error: 'invalid_token'
                    }));
            }
        });
    }
});

expressApp.get('/refresh_token', function (req, res) {

    // requesting access token from refresh token
    const refresh_token = req.query.refresh_token;
    log.info("SPOTIFY: refresh_token", refresh_token);

    const authOptions = {
        url: 'https://accounts.spotify.com/api/token',
        headers: {'Authorization': 'Basic ' + (new Buffer(client_id + ':' + client_secret).toString('base64'))},
        form: {
            grant_type: 'refresh_token',
            refresh_token: refresh_token
        },
        json: true
    };

    request.post(authOptions, function (error, response, body) {
        log.info(body);
        if (!error && response.statusCode === 200) {
            const access_token = body.access_token;
            res.send({
                'access_token': access_token
            });
        }
    });
});

log.info("SPOTIFY: check PORT", PORT, "PID", pid);

function listen () {
    log.info('SPOTIFY: service starting on 8888');
    expressApp.listen(PORT, "localhost");
}

tcpPortUsed.check(PORT)
    .then(function (inUse) {
        log.info("SPOTIFY: in use", inUse);
        if (inUse) {
            log.error("SPOTIFY: Port already in use:", PORT);
            process.exit(1);
        } else {
            setTimeout(listen, 1000);
        }
    }, function (err) {
        log.error('SPOTIFY: Error on check:', err.message);
        process.exit(1);
    });
