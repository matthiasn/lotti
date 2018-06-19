"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
require("react-native");
var react_1 = __importDefault(require("react"));
var App_1 = __importDefault(require("../App"));
// Note: test renderer must be required after react-native.
var react_test_renderer_1 = __importDefault(require("react-test-renderer"));
it('renders correctly', function () {
    var tree = react_test_renderer_1.default.create(react_1.default.createElement(App_1.default, null));
});
