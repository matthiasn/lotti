"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    Object.defineProperty(o, k2, { enumerable: true, get: function() { return m[k]; } });
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
var electron_1 = require("electron");
var path = __importStar(require("path"));
var electron = __importStar(require("electron"));
var loglevel_1 = __importDefault(require("loglevel"));
function createWindow() {
    loglevel_1.default.setDefaultLevel('info');
    loglevel_1.default.info('App is ready');
    var _a = electron.screen.getPrimaryDisplay().workAreaSize, width = _a.width, height = _a.height;
    var win = new electron_1.BrowserWindow({
        width: width - 100,
        height: width - 100,
        webPreferences: {
            nodeIntegration: true,
        },
    });
    var indexHTML = path.join(__dirname + '/index.html');
    win.loadFile(indexHTML).then(function () {
        loglevel_1.default.info('Main window loaded');
    });
}
electron_1.app.whenReady().then(createWindow);
