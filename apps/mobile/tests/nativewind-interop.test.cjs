const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const test = require('node:test');
const { runInNewContext } = require('node:vm');

test('NativeWind registers View and Image without reading the deprecated ImageBackground export', () => {
  const registered = new Set();
  const runtime = require.resolve('react-native-css-interop/dist/runtime/components.js');
  const reactNative = {
    Image: Symbol('Image'),
    View: Symbol('View'),
    get ImageBackground() {
      throw new Error('The React Native deprecation getter was accessed');
    },
  };
  const api = {
    cssInterop: (component) => registered.add(component),
    remapProps: () => {},
  };

  runInNewContext(readFileSync(runtime, 'utf8'), {
    exports: {},
    require(name) {
      if (name === 'react-native') return reactNative;
      if (name === './api') return api;
      if (name === 'react-native-safe-area-context') return {};
      throw new Error(`Unexpected runtime import: ${name}`);
    },
  }, { filename: runtime });

  assert.ok(registered.has(reactNative.View));
  assert.ok(registered.has(reactNative.Image));
});
