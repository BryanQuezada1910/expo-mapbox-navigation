const assert = require('node:assert/strict');
const test = require('node:test');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');

function load(relative, modules = {}) {
  const file = path.join(__dirname, '../src', relative);
  const module = { exports: {} };
  const source = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, esModuleInterop: true }
  }).outputText;
  vm.runInNewContext(source, { module, exports: module.exports, require: name => modules[name], console });
  return module.exports;
}
const geometry = load('utils/planned-route/routeGeometry.ts');
const localization = load('utils/localization/navigationLocale.ts', {
  '../../configs/localization/navigationStrings.json': require('../src/configs/localization/navigationStrings.json'),
});
const points = count => Array.from({ length: count }, (_, index) => ({ latitude: 19 + index / 100000, longitude: -99 + index / 100000 }));
for (const count of [2, 100, 101, 1000, 1001, 10000]) {
  test('all ' + count + ' points remain covered, with exact overlaps', () => {
    const coordinates = points(count), chunks = geometry.createRouteChunks(coordinates);
    const covered = new Set();
    for (const chunk of chunks) {
      assert.ok(chunk.coordinates.length <= 100 && chunk.coordinates.length >= 2);
      for (let index = chunk.start; index <= chunk.end; index++) {
        covered.add(index);
        assert.equal(chunk.coordinates[index - chunk.start], coordinates[index]);
      }
    }
    assert.equal(covered.size, count);
    for (let index = 1; index < chunks.length; index++) assert.equal(chunks[index - 1].end - chunks[index].start + 1, 20);
  });
}
test('interior changes invalidate the identity with unchanged ends and count', () => {
  const original = points(100), changed = original.map(point => ({ ...point }));
  changed[50].longitude += 0.001;
  assert.notEqual(geometry.routeIdentity(original), geometry.routeIdentity(changed));
});
test('projection follows line edges and rejects off-route GPS', () => {
  const coordinates = [{ latitude: 19, longitude: -99 }, { latitude: 19, longitude: -98.99 }];
  const distances = geometry.cumulativeDistances(coordinates);
  const inside = geometry.projectLocation(coordinates, distances, { latitude: 19, longitude: -98.995 });
  assert.ok(inside.offset < 1);
  assert.ok(Math.abs(inside.distance / distances[1] - 0.5) < 0.001);
  const outside = geometry.projectLocation(coordinates, distances, { latitude: 19.001, longitude: -98.995 });
  assert.ok(outside.offset > 100);
});
test('a crossing retains the occurrence closest to earlier progress', () => {
  const coordinates = [
    { latitude: 19, longitude: -99.001 }, { latitude: 19, longitude: -98.999 },
    { latitude: 19.001, longitude: -99 }, { latitude: 18.999, longitude: -99 }
  ];
  const distances = geometry.cumulativeDistances(coordinates);
  const point = { latitude: 19, longitude: -99 };
  assert.equal(geometry.projectLocation(coordinates, distances, point, 0, 3, 100).index, 0);
  assert.equal(geometry.projectLocation(coordinates, distances, point, 0, 3, distances[2] + 100).index, 2);
});
test('window switches inside overlap before artificial destination', () => {
  const chunks = geometry.createRouteChunks(points(201));
  assert.equal(geometry.chunkForProjection(chunks, { index: 84 }), 0);
  assert.equal(geometry.chunkForProjection(chunks, { index: 85 }), 1);
  assert.equal(geometry.chunkForProjection(chunks, { index: 165 }), 2);
});

function setupHook(coordinates) {
  const slots = [], effects = [], timers = new Map();
  let cursor = 0, dirty = false, result;
  const events = [], reports = [];
  const same = (first, second) => first && second && first.length === second.length && first.every((value, index) => Object.is(value, second[index]));
  const react = {
    useState(initial) {
      const index = cursor++;
      if (!slots[index]) slots[index] = { value: initial };
      return [slots[index].value, value => {
        const next = typeof value === 'function' ? value(slots[index].value) : value;
        if (!Object.is(next, slots[index].value)) { slots[index].value = next; dirty = true; }
      }];
    },
    useRef(initial) {
      const index = cursor++;
      if (!slots[index]) slots[index] = { current: initial };
      return slots[index];
    },
    useMemo(callback, dependencies) {
      const index = cursor++;
      if (!slots[index] || !same(slots[index].dependencies, dependencies))
        slots[index] = { value: callback(), dependencies };
      return slots[index].value;
    },
    useCallback(callback, dependencies) { return react.useMemo(() => callback, dependencies); },
    useEffect(callback, dependencies) {
      const index = cursor++;
      const previous = slots[index];
      if (!previous || !same(previous.dependencies, dependencies)) {
        slots[index] = { dependencies, cleanup: previous?.cleanup };
        effects.push(() => { slots[index].cleanup?.(); slots[index].cleanup = callback(); });
      }
    }
  };
  const source = fs.readFileSync(path.join(__dirname, '../src/hooks/planned-route/usePlannedRoute.ts'), 'utf8');
  const module = { exports: {} };
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText, {
    module, exports: module.exports,
    require: name => name === 'react' ? react : name === 'react-native' ? { AppState: { addEventListener: () => ({ remove() {} }) } } : name.includes('navigationLocale') ? localization : geometry,
    setTimeout: callback => { const id = timers.size; timers.set(id, callback); return id; },
    clearTimeout: id => timers.delete(id), console
  });
  const props = { coordinates, routeMode: 'planned', plannedRouteDistance: 2000, plannedRouteDuration: 100,
    onGuidanceStateChanged: event => { events.push(event.nativeEvent.state); reports.push(event.nativeEvent); } };
  const render = () => {
    let runs = 0;
    do {
      dirty = false; cursor = 0;
      result = module.exports.usePlannedRoute(props);
      while (effects.length) effects.shift()();
      assert.ok(++runs < 20, 'hook must settle without a render loop');
    } while (dirty);
    return result;
  };
  return { render, props, events, reports, timers };
}

test('invalid-geometry messages update when only locale changes', () => {
  const harness = setupHook([]);
  harness.props.locale = 'es-MX';
  harness.render();
  assert.equal(harness.reports.at(-1).errorMessage, 'Geometría de ruta inválida');
  harness.props.locale = 'en-US';
  harness.render();
  assert.equal(harness.reports.at(-1).errorMessage, 'Invalid route geometry');
});

test('locale changes invalidate instructions without replacing the original trace', () => {
  const coordinates = points(201), harness = setupHook(coordinates);
  harness.props.locale = 'es-MX';
  let view = harness.render();
  view.onPlannedRouteLocation({ nativeEvent: coordinates[20] });
  view = harness.render();
  const previousRevision = view.routeRevision;
  view.onRoutesLoaded({ nativeEvent: { routeRevision: previousRevision, routes: {} } });
  assert.equal(harness.render().guidanceEnabled, true);
  harness.props.locale = 'en-US';
  view = harness.render();
  assert.notEqual(view.routeRevision, previousRevision);
  assert.equal(view.guidanceEnabled, false);
  assert.equal(view.isOnPlannedRoute, true);
  assert.equal(view.plannedRouteCoordinates, coordinates);
  view.onRoutesLoaded({ nativeEvent: { routeRevision: previousRevision, routes: {} } });
  assert.equal(harness.render().guidanceEnabled, false);
  view.onRoutesLoaded({ nativeEvent: { routeRevision: view.routeRevision, routes: {} } });
  assert.equal(harness.render().guidanceEnabled, true);
});
test('guidance follows original windows without replacing full geometry', () => {
  const coordinates = points(201), harness = setupHook(coordinates);
  let view = harness.render();
  const firstRevision = view.routeRevision;
  assert.equal(view.guidanceStatus, 'preparing');
  assert.equal(view.isOnPlannedRoute, undefined);
  assert.equal(view.plannedRouteCoordinates, coordinates);
  assert.equal(view.coordinates.length, 100);
  view.onPlannedRouteLocation({ nativeEvent: coordinates[0] });
  view = harness.render();
  view.onRoutesLoaded({ nativeEvent: { routeRevision: view.routeRevision, routes: {} } });
  view = harness.render();
  assert.equal(view.guidanceEnabled, true);
  assert.equal(view.isOnPlannedRoute, true);
  assert.equal(view.guidanceStatus, 'available');
  view.onPlannedRouteLocation({ nativeEvent: { latitude: 20, longitude: -100 } });
  view = harness.render();
  assert.equal(view.guidanceEnabled, false);
  assert.equal(view.guidanceStatus, 'off-route');
  assert.equal(view.isOnPlannedRoute, false);
  assert.equal(view.plannedRouteCoordinates, coordinates);
  view.onPlannedRouteLocation({ nativeEvent: coordinates[90] });
  view = harness.render();
  assert.equal(view.coordinates[0], coordinates[80]);
  assert.equal(view.isOnPlannedRoute, true);
  assert.equal(view.guidanceStatus, 'preparing');
  assert.equal(view.guidanceEnabled, false);
  assert.equal(view.onFinalDestinationArrival, undefined);
  view.onRoutesLoaded({ nativeEvent: { routeRevision: firstRevision, routes: {} } });
  view = harness.render();
  assert.equal(view.guidanceEnabled, false, 'late earlier-window response is rejected');
  view.onRoutesLoaded({ nativeEvent: { routeRevision: view.routeRevision, routes: {} } });
  view = harness.render();
  assert.equal(view.guidanceEnabled, true);
  assert.equal(view.guidanceStatus, 'available');
  assert.ok(view.plannedRouteProgress.fractionTraveled > 0.4);
  assert.equal(view.reroutingEnabled, false);
  assert.equal(view.useRouteMatchingApi, true);
});

test('GPS alone cannot mark guidance available while changing windows or retrying', () => {
  const coordinates = points(201), harness = setupHook(coordinates);
  let view = harness.render();
  view.onPlannedRouteLocation({ nativeEvent: coordinates[10] });
  view = harness.render();
  assert.equal(view.isOnPlannedRoute, true);
  assert.equal(harness.events.at(-1), 'preparing');
  view.onRoutesLoaded({ nativeEvent: { routeRevision: view.routeRevision, routes: {} } });
  view = harness.render();
  view.onPlannedRouteLocation({ nativeEvent: coordinates[90] });
  view = harness.render();
  assert.equal(view.guidanceEnabled, false);
  assert.equal(view.isOnPlannedRoute, true);
  assert.equal(harness.events.at(-1), 'preparing', 'a new window needs its own matching response');
  view.onRouteFailedToLoad({ nativeEvent: { routeRevision: view.routeRevision, errorMessage: 'NoMatch' } });
  view = harness.render();
  assert.equal(view.guidanceStatus, 'unavailable');
  assert.equal(view.isOnPlannedRoute, true);
  assert.equal(harness.events.at(-1), 'unavailable');
  assert.equal(harness.timers.size, 1, 'matching still retries while no maneuver is shown');
  view.onPlannedRouteLocation({ nativeEvent: { latitude: 20, longitude: -100 } });
  view = harness.render();
  assert.equal(view.isOnPlannedRoute, false);
  assert.equal(view.guidanceStatus, 'off-route', 'off-route status takes precedence over a matching failure');
});
test('a matching failure preserves drawing and retries the same original block', () => {
  const harness = setupHook(points(1001));
  let view = harness.render();
  const revision = view.routeRevision, block = view.coordinates;
  view.onRouteFailedToLoad({ nativeEvent: { routeRevision: revision, errorMessage: 'NoMatch' } });
  view = harness.render();
  assert.equal(view.guidanceEnabled, false);
  assert.equal(view.plannedRouteCoordinates.length, 1001);
  assert.equal(view.guidanceStatus, 'unavailable');
  assert.ok(harness.events.includes('unavailable'));
  assert.equal(harness.timers.size, 1);
  [...harness.timers.values()][0]();
  view = harness.render();
  assert.notEqual(view.routeRevision, revision);
  assert.equal(view.coordinates, block);
  assert.equal(view.guidanceStatus, 'preparing');
});

test('rejoining restores available instructions without requesting another route', () => {
  const coordinates = points(101), harness = setupHook(coordinates);
  let view = harness.render();
  const revision = view.routeRevision;
  view.onRoutesLoaded({ nativeEvent: { routeRevision: revision, routes: {} } });
  view = harness.render();
  assert.equal(view.guidanceStatus, 'off-route');
  view.onPlannedRouteLocation({ nativeEvent: coordinates[30] });
  view = harness.render();
  assert.equal(view.guidanceStatus, 'available');
  view.onPlannedRouteLocation({ nativeEvent: { latitude: 20, longitude: -100 } });
  view = harness.render();
  assert.equal(view.guidanceStatus, 'off-route');
  view.onPlannedRouteLocation({ nativeEvent: coordinates[40] });
  view = harness.render();
  assert.equal(view.guidanceStatus, 'available');
  assert.equal(view.routeRevision, revision);
  assert.equal(view.guidanceEnabled, true);
});

test('planned off-route events follow the original trace once per excursion, including initial GPS', () => {
  const coordinates = points(201), harness = setupHook(coordinates);
  let deviations = 0;
  harness.props.onUserOffRoute = () => { deviations++; };
  let view = harness.render();
  assert.equal(deviations, 0, 'preparing without GPS is not a deviation');
  assert.equal(view.onUserOffRoute, undefined, 'native matching-window deviations are suppressed');
  const outside = { nativeEvent: { latitude: 20, longitude: -100 } };
  view.onPlannedRouteLocation({ nativeEvent: { latitude: NaN, longitude: -99 } });
  assert.equal(deviations, 0);
  view.onPlannedRouteLocation(outside);
  view.onPlannedRouteLocation(outside);
  view = harness.render();
  assert.equal(deviations, 1);
  view.onRouteFailedToLoad({ nativeEvent: { routeRevision: view.routeRevision, errorMessage: 'NoMatch' } });
  harness.props.locale = 'en-US';
  view = harness.render();
  view.onPlannedRouteLocation(outside);
  assert.equal(deviations, 1, 'matching failures and locale changes do not rearm an excursion');
  view.onPlannedRouteLocation({ nativeEvent: coordinates[90] });
  view = harness.render();
  view.onPlannedRouteLocation(outside);
  assert.equal(deviations, 2);
  const old = view.onPlannedRouteLocation;
  harness.props.coordinates = [{ latitude: 18, longitude: -98 }, { latitude: 18.001, longitude: -98 }];
  view = harness.render();
  old(outside);
  assert.equal(deviations, 2, 'old trace callbacks cannot report for a new route');
  view.onPlannedRouteLocation(outside);
  assert.equal(deviations, 3);
});

test('calculated navigation preserves the native off-route callback', () => {
  const harness = setupHook(points(2));
  harness.props.routeMode = 'calculated';
  const callback = () => {};
  harness.props.onUserOffRoute = callback;
  assert.equal(harness.render().onUserOffRoute, callback);
});
