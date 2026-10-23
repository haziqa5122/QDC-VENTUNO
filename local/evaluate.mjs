// Evaluate the HTTP JSON saved by board/03-batch-infer.sh.
import fs from 'node:fs';
import { readResults, stats } from './results.mjs';
const [resultsPath, ledgerPath] = process.argv.slice(2);
if (!resultsPath) {
    console.error('Usage: node local/evaluate.mjs <results.txt> [ledger.csv]');
    process.exit(1);
}
try {
    const { rows, errors, total } = readResults(resultsPath);
    if (errors.length) {
        console.error(errors.join('\n'));
        console.error('Evaluation stopped: failed or unlabelled samples must not be silently excluded from accuracy.');
        process.exit(1);
    }
    if (!rows.length) throw new Error('No result blocks found.');
    const correct = rows.filter(r => r.truth === r.pred).length;
    console.log(`Images scored: ${rows.length}/${total}`);
    console.log(`Top-1 accuracy: ${(100 * correct / rows.length).toFixed(1)}% (${correct}/${rows.length})`);
    const labels = [...new Set(rows.flatMap(r => [r.truth, r.pred]))].sort();
    const matrix = Object.fromEntries(labels.map(t => [t, Object.fromEntries(labels.map(p => [p, 0]))]));
    for (const r of rows) matrix[r.truth][r.pred]++;
    console.log('Confusion matrix (rows = true class, columns = predicted):');
    console.table(matrix);
    console.log('Latency (ms; runner timings are separate from the HTTP round trip):');
    console.table({
        'HTTP request round trip': stats(rows.map(r => r.wallMs)),
        'Runner classification': stats(rows.map(r => r.classificationMs)),
        'Runner preprocessing (DSP)': stats(rows.map(r => r.dspMs)),
    });
    const wrong = rows.filter(r => r.truth !== r.pred);
    if (wrong.length) { console.log('Misclassified:'); console.table(wrong.map(({ file, pred, conf }) => ({ file, pred, confidence: conf }))); }
    console.log('Top-1 scoring has no confidence threshold. Match model variant, preprocessing and scoring rules before comparing with Studio.');
    if (ledgerPath) {
        const lines = fs.readFileSync(ledgerPath, 'utf8').trim().split(/\r?\n/);
        if (lines.shift() !== 'epoch,time,phase') throw new Error('Unexpected ledger CSV header.');
        const entries = lines.map(l => { const [epoch, time, phase] = l.split(','); return { epoch: Number(epoch), time, phase }; });
        if (!entries.length || entries.some(l => !Number.isFinite(l.epoch) || !l.time || !l.phase)) throw new Error('Invalid or empty ledger.');
        console.log('Ledger elapsed minutes (excludes session time before first entry and after last entry):');
        console.table(entries.map(l => ({ phase: l.phase, time: l.time, minutes: +((l.epoch - entries[0].epoch) / 60).toFixed(2) })));
        console.log('The ledger does not measure QDC minute usage. Check the QDC session report separately.');
    }
} catch (error) { console.error(error.message); process.exitCode = 1; }
