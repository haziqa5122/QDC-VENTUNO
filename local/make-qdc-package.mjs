// Optional helper: packages board scripts with your own held-out test images.
// Everything the session needs goes up in one file, so no minutes are spent on
// uploading files one by one through the file browser.
//
//   node local/make-qdc-package.mjs [path-to-test-images]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import AdmZip from 'adm-zip';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const testDir = process.argv[2]
    ? path.resolve(process.argv[2])
    : path.join(root, 'test-images');
const boardDir = path.join(root, 'board');
const outZip = process.argv[3] ? path.resolve(process.argv[3]) : path.join(root, 'out', 'qdc-package.zip');

if (!fs.existsSync(testDir) || !fs.statSync(testDir).isDirectory()) {
    console.error(`Test-image folder not found: ${testDir}`);
    console.error('Add your held-out JPEG/PNG images to test-images/ or pass their folder path.');
    process.exit(1);
}
const images = fs.readdirSync(testDir).filter(f =>
    /\.(jpe?g|png)$/i.test(f) && fs.statSync(path.join(testDir, f)).isFile()).sort();
if (!images.length) {
    console.error(`No JPEG/PNG test images found in ${testDir}. Add your own held-out images first.`);
    process.exit(1);
}

if (images.some(f => /[\r\n"\\]/.test(f))) {
    console.error('Image names must not contain quotes, backslashes or newlines.');
    process.exit(1);
}
const zip = new AdmZip();
for (const f of ['00-ledger.sh', '01-setup.sh', '02-connect.sh', '03-batch-infer.sh']) {
    // LF line endings, or sh on the board chokes on \r
    const text = fs.readFileSync(path.join(boardDir, f), 'utf8').replace(/\r\n/g, '\n');
    zip.addFile(`board/${f}`, Buffer.from(text, 'utf8'));
    zip.getEntry(`board/${f}`).attr = (0o100755 << 16) >>> 0; // -rwxr-xr-x for unzip on Linux
}
for (const f of images) zip.addLocalFile(path.join(testDir, f), 'test-images');

fs.mkdirSync(path.dirname(outZip), { recursive: true });
zip.writeZip(outZip);
console.log(`Wrote ${outZip} (${images.length} test images, ${(fs.statSync(outZip).size / 2 ** 20).toFixed(2)} MB)`);
