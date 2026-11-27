const assert = require('node:assert/strict');
const test = require('node:test');

const { demoRecords, loadDemoPortal } = require('../src/features/patient/demo.ts');
const { filterRecords, initialFilters, paginateRecords } = require('../src/features/patient/model.ts');

test('record filters combine search, hospital, category, status and inclusive dates', () => {
  const result = filterRecords(demoRecords, {
    ...initialFilters,
    search: ' dr. neha ',
    hospital: 'Greenfield Medical Centre',
    category: 'Lab Reports',
    status: 'Verified',
    from: '2026-11-20',
    to: '2026-11-20',
  });
  assert.deepEqual(result.map(({ id }) => id), ['demo-01']);
  assert.deepEqual(filterRecords(demoRecords, { ...initialFilters, from: '2026-11-21', to: '2026-11-20' }), []);
});

test('sorting leaves the demo records intact and pagination handles out-of-range pages', () => {
  const oldest = filterRecords(demoRecords, { ...initialFilters, sort: 'oldest' });
  assert.equal(oldest[0].id, 'demo-14');
  const alphabetical = filterRecords(demoRecords, { ...initialFilters, sort: 'name' });
  assert.equal(alphabetical[0].name, 'Chest X-ray report');
  assert.equal(demoRecords[0].id, 'demo-01');
  assert.deepEqual(paginateRecords(demoRecords, 10, 6), { page: 3, pageCount: 3, items: demoRecords.slice(12) });
  assert.deepEqual(paginateRecords([], 2, 6), { page: 1, pageCount: 1, items: [] });
});

test('sample records have matching documents and keep patient uploads separate', () => {
  for (const record of demoRecords) {
    assert.doesNotThrow(() => require.resolve(`../public/patient-demo/${record.id}.pdf`), record.id);
    if (['Pending Review', 'Patient Uploaded'].includes(record.status)) {
      assert.equal(record.source, 'Patient upload');
    }
  }
});

test('demo loading fails while offline, succeeds after reconnecting and honors cancellation', async () => {
  const controller = new AbortController();
  const property = Object.getOwnPropertyDescriptor(globalThis, 'navigator');
  try {
    Object.defineProperty(globalThis, 'navigator', { configurable: true, value: { onLine: false } });
    await assert.rejects(loadDemoPortal(controller.signal), /offline/);
    Object.defineProperty(globalThis, 'navigator', { configurable: true, value: { onLine: true } });
    assert.equal((await loadDemoPortal(controller.signal)).patient.id, 'DEMO-001');
    controller.abort();
    await assert.rejects(loadDemoPortal(controller.signal), { name: 'AbortError' });
  } finally {
    if (property) Object.defineProperty(globalThis, 'navigator', property);
    else delete globalThis.navigator;
  }
});
