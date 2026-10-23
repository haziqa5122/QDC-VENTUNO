import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { parseResults, stats } from '../results.mjs';
import AdmZip from 'adm-zip';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const block = (file, response, ms = 100) => `### ${file} ${ms}\n${JSON.stringify(response)}\n`;
const good = { result: { classification: { daisy: 0.9, roses: 0.1 } }, timing: { classification: 2, dsp: 1 } };

test('HTTP scores, filename with spaces, and separate timings', () => {
    const { rows, errors } = parseResults(block('daisy.sample one.jpg', good));
    assert.deepEqual(errors, []);
    assert.equal(rows[0].pred, 'daisy');
    assert.equal(rows[0].classificationMs, 2);
    assert.equal(rows[0].dspMs, 1);
});
test('timing-only or error JSON is never treated as class scores', () => {
    for (const response of [{ timing: { classification: 2, dsp: 1 } }, { error: 'failed' }]) {
        const parsed = parseResults(block('daisy.0.jpg', response));
        assert.equal(parsed.rows.length, 0);
        assert.equal(parsed.errors.length, 1);
    }
});
test('malformed JSON, duplicates, unknown truth labels and all-zero scores fail', () => {
    assert.equal(parseResults('### daisy.0.jpg 1\n{broken\n').errors.length, 1);
    assert.equal(parseResults(block('daisy.0.jpg', good).repeat(2)).errors.length, 1);
    assert.equal(parseResults(block('unknown.0.jpg', good)).errors.length, 1);
    assert.equal(parseResults(block('daisy.0.jpg', { classification: { daisy: 0, roses: 0 } })).errors.length, 1);
});
test('quotes and braces in class labels are valid JSON', () => {
    const result = parseResults(block('flower{.1.png', { classification: { 'flower{': 0.8, other: 0.2 } }));
    assert.deepEqual(result.errors, []);
});
test('stats exclude missing values rather than counting them as zero', () => {
    assert.equal(stats([null, undefined]), null);
    assert.deepEqual(stats([null, 1, 3]), { n: 2, mean: 2, p50: 1, p95: 3, max: 3 });
});
test('CLI refuses a partial failed run instead of reporting inflated accuracy', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'qdc-eval-'));
    try {
        const file = path.join(dir, 'results.txt');
        fs.writeFileSync(file, block('daisy.0.jpg', good) + block('roses.0.jpg', { error: 'failed' }));
        const r = spawnSync(process.execPath, [path.join(root, 'local/evaluate.mjs'), file], { encoding: 'utf8' });
        assert.equal(r.status, 1);
        assert.match(r.stderr, /Evaluation stopped/);
        assert.doesNotMatch(r.stdout, /accuracy/);
    } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
test('package has correct roots, names, permissions and LF shell scripts', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'qdc-package-'));
    try {
        // Valid 1x1 PNG; no downloaded photos or third-party dataset required.
        fs.writeFileSync(path.join(dir, 'daisy.example.png'), Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=', 'base64'));
        fs.writeFileSync(path.join(dir, 'ignored.txt'), 'do not package');
        const output = path.join(dir, 'package.zip');
        const r = spawnSync(process.execPath, [path.join(root, 'local/make-qdc-package.mjs'), dir, output], { encoding: 'utf8' });
        assert.equal(r.status, 0, r.stderr);
        const zip = new AdmZip(output);
        const entries = zip.getEntries();
        assert.equal(entries.length, 5);
        assert.ok(zip.getEntry('test-images/daisy.example.png'));
        for (const entry of entries.filter(e => e.entryName.endsWith('.sh'))) {
            assert.equal((entry.attr >>> 16) & 0o777, 0o755);
            assert.ok(!zip.readAsText(entry).includes('\r'));
        }
    } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
test('empty test-image folder fails before overwriting any upload archive', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'qdc-empty-'));
    try {
        const r = spawnSync(process.execPath, [path.join(root, 'local/make-qdc-package.mjs'), dir], { encoding: 'utf8' });
        assert.equal(r.status, 1);
        assert.match(r.stderr, /No JPEG\/PNG/);
    } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
