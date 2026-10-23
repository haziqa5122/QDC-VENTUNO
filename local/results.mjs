import fs from 'node:fs';

export function parseResults(text) {
    const chunks = text.split(/^### /m);
    const rows = [], errors = [];
    if (chunks[0].trim()) errors.push('Unexpected text before first result header.');
    const seen = new Set();
    for (const chunk of chunks.slice(1)) {
        const nl = chunk.indexOf('\n');
        const header = chunk.slice(0, nl < 0 ? undefined : nl).trim();
        const match = header.match(/^(.+\.(?:jpe?g|png))\s+(\d+(?:\.\d+)?)$/i);
        if (!match || nl < 0) { errors.push(`Invalid result header: ${header}`); continue; }
        const [, file, wall] = match;
        if (seen.has(file)) { errors.push(`Duplicate result: ${file}`); continue; }
        seen.add(file);
        const dot = file.indexOf('.');
        const truth = file.slice(0, dot);
        let response;
        try { response = JSON.parse(chunk.slice(nl + 1)); }
        catch { errors.push(`Invalid JSON: ${file}`); continue; }
        const scores = response?.result?.classification ?? response?.classification;
        if (!scores || Array.isArray(scores) || typeof scores !== 'object' ||
            !Object.keys(scores).length || !Object.values(scores).every(v => Number.isFinite(v) && v >= 0 && v <= 1)) {
            errors.push(`Missing or invalid classification scores: ${file}`); continue;
        }
        if (!Object.hasOwn(scores, truth)) {
            errors.push(`Filename label '${truth}' is not a model class: ${file}`); continue;
        }
        if (Math.max(...Object.values(scores)) === 0) {
            errors.push(`All class scores are zero: ${file}`); continue;
        }
        const [pred, conf] = Object.entries(scores).sort((a, b) => b[1] - a[1])[0];
        const timing = response.timing ?? {};
        const ms = name => Number.isFinite(timing[name]) && timing[name] >= 0 ? timing[name] : null;
        rows.push({ file, truth, pred, conf, wallMs: Number(wall), classificationMs: ms('classification'), dspMs: ms('dsp') });
    }
    return { rows, errors, total: chunks.length - 1 };
}

export function stats(values) {
    const s = values.filter(v => typeof v === 'number' && Number.isFinite(v)).sort((a, b) => a - b);
    if (!s.length) return null;
    const q = p => s[Math.max(0, Math.ceil(s.length * p) - 1)];
    return { n: s.length, mean: +(s.reduce((a, b) => a + b, 0) / s.length).toFixed(2), p50: q(0.5), p95: q(0.95), max: s.at(-1) };
}

export function readResults(file) { return parseResults(fs.readFileSync(file, 'utf8')); }
