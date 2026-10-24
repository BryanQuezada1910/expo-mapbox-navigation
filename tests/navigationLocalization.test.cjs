const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const ts = require('typescript');
const { execFileSync } = require('node:child_process');
const catalog = require('../src/configs/localization/navigationStrings.json');
const cases = require('./navigationLocalizationCases.json');

for (const fixture of cases) {
  test('navigation strings for ' + JSON.stringify(fixture), () => {
    const module = { exports: {} };
    const source = fs.readFileSync(path.join(__dirname, '../src/utils/localization/navigationLocale.ts'), 'utf8');
    vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, esModuleInterop: true } }).outputText, {
      module, exports: module.exports, require: () => catalog,
      Intl: { DateTimeFormat: () => ({ resolvedOptions: () => ({ locale: fixture.systemLocale }) }) },
    });
    assert.equal(module.exports.navigationLanguage(fixture.locale), fixture.language);
    assert.equal(module.exports.navigationStrings(fixture.locale).webUnsupported, catalog[fixture.language].webUnsupported);
  });
}

test('native catalogs remain synchronized with the shared catalog', () => {
  execFileSync(process.execPath, ['scripts/generateNavigationStrings.cjs', '--check'], { cwd: path.join(__dirname, '..') });
});
