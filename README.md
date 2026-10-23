# Try Arduino VENTUNO Q without owning a board

Companion scripts for training an image classifier in Edge Impulse Studio and
validating it on a remote Arduino VENTUNO Q through Qualcomm Device Cloud (QDC).
Prepare and train on your computer and in Studio, then reserve device time for
inference on real hardware.

This is an independent tutorial project, not an official Arduino, Qualcomm or
Edge Impulse SDK. Device access and minute allowances depend on your QDC account.

## Requirements

- An [Edge Impulse Studio](https://studio.edgeimpulse.com) project with a trained
  image classifier and a project API key.
- A [QDC account](https://qdc.qualcomm.com) with access to Arduino VENTUNO Q.
- Node.js **20 or later** and npm on your computer for the optional ZIP builder
  and evaluator (Windows, macOS or Linux).
- OpenSSH on your computer; an SSH key registered with QDC.
- Your held-out JPEG/PNG test images. Photos, trained models and credentials are
  deliberately not included in this repository.

The board scripts target **Ubuntu on VENTUNO Q**, with sudo access and internet.
The installer uses NodeSource Node.js 20 when a suitable Node.js is missing and
pins `edge-impulse-linux` to **1.25.2**, the version used in the recorded run.
This older CLI can have upstream dependency warnings; review [SECURITY.md](SECURITY.md).
Override the pin only after testing the replacement:
`EI_LINUX_VERSION=<version> sh 01-setup.sh`.

## 1. Train in Studio before starting the clock

1. Create an **image-classification** project. Under Dashboard / Project info,
   use **One label per data item** as the labeling method.
2. Upload and label images in Data acquisition. Separate training and test data;
   keep duplicates and related captures together to avoid test leakage.
3. Select **Arduino VENTUNO Q (Qualcomm QCS8275)** as the target device if available.
4. Create an impulse with Image and Transfer Learning (Images) blocks. The
   tutorial example used 160 x 160, **Fit shortest axis**, RGB, MobileNetV2
   160x160 0.35, 30 cycles, learning rate 0.0005, and data augmentation.
5. Generate features, train, and run Model testing. Choose **Quantized (int8)**
   for the Qualcomm QNN deployment route used in this tutorial.

The board target used for estimates and the deployment backend are separate
settings. The recorded deployment used **Linux (AARCH64 with Qualcomm QNN)**.
Low latency or visible FastRPC device nodes alone do not establish NPU execution;
check the deployment/backend logs when making acceleration claims.

You can use any labeled image dataset. The article used three classes from
[TensorFlow Flowers](https://www.tensorflow.org/datasets/catalog/tf_flowers).
Follow the source image license and attribution requirements if using that dataset;
the repository's MIT license does not license third-party photos or platform software.

## 2. Build the session upload

Put held-out images directly in `test-images/` (no subfolders). To score accuracy,
use names such as `daisy.0000.jpg`, `roses.0000.png`: the part before the **first
period** is the true class and must exactly match a model class. Class labels
containing periods are not supported by the scoring helper. Spaces in the image
identifier are supported. Avoid quotes, backslashes and newlines in filenames.

From the repository root:

```bash
npm ci --prefix local
node local/make-qdc-package.mjs
```

This creates `out/qdc-package.zip` with these roots:

```text
board/
  00-ledger.sh
  01-setup.sh
  02-connect.sh
  03-batch-infer.sh
test-images/
  daisy.0000.jpg
  ...
```

The builder sorts filenames, normalizes shell scripts to LF, and assigns Unix
read/execute permissions. It fails if there are no images. It **overwrites** the
previous generated ZIP. To use another image folder:

```bash
node local/make-qdc-package.mjs /path/to/test-images
```

Alternatively ZIP `board/` and your `test-images/` manually, preserving LF line
endings and readable permissions. Neither local helper uploads data to Studio or QDC.

## 3. Start a capped QDC session

Select Arduino VENTUNO Q, review its current access requirements, enable Wi-Fi
if needed for connectivity, choose **SSH only**, register your SSH public key,
and attach the ZIP under **Package Upload**. Set a short session cap (for example
20 minutes); availability, software installation and downloads can vary.

Use **Connect** to get the commands for this particular session. Open two local
terminals: keep the SSH tunnel running in the first and log into the board through
it in the second. Hostnames, credentials and keys are session-specific; use QDC's
values. On Windows, QDC's `/dev/null` known-hosts path may need to be `NUL`.

The following commands run **on the remote board**, not in local PowerShell:

```sh
mkdir -p ~/qdc
cp -r /tmp/QDC_files/* ~/qdc/
cd ~/qdc/board
. ./00-ledger.sh
ledger session_start
sh 01-setup.sh
. ~/.profile
```

Our upload appeared in `/tmp/QDC_files/`, despite the dialog naming
`/data/local/tmp/QDC_files/`. If copying fails, inspect both paths rather than
assuming that the upload is missing. Ordinary QDC sessions may reset the environment;
keep the ZIP ready for each session. The installer reports WARM only when the
requested CLI version is already installed; this is not a persistence guarantee.

## 4. Download and run the model

In the board's default Bash shell, read the project key without putting it into
shell history:

```bash
read -r -s -p 'Edge Impulse project API key: ' EI_API_KEY
printf '\n'
export EI_API_KEY
sh 02-connect.sh
unset EI_API_KEY
```

The CLI receives the key for authentication. Keep it out of screenshots and logs.
Choose **Quantized (int8)** when prompted and check the selected deployment target.
The script saves `~/qdc/model.eim`. If the selected build is not the intended QNN
variant, correct the deployment choice before comparing performance.

Run the complete test folder:

```sh
sh 03-batch-infer.sh ~/qdc/test-images
ledger session_end
```

The batch script starts one runner HTTP server, waits for readiness, POSTs each
image to `/api/image`, and stops **its own server** on exit. It fails on request
errors and retains partial output. It refuses an existing results file and a port
already serving HTTP, so an earlier run cannot silently supply the wrong model.
Use fresh output filenames for another candidate:

```sh
MODEL="$HOME/qdc/model.eim" OUT="$HOME/qdc/results-second.txt" PORT=1338 \
  sh 03-batch-infer.sh ~/qdc/test-images
```

Responses are saved as JSON blocks headed by `### filename elapsed_ms` in
`~/qdc/results.txt`. The ledger is `~/qdc/ledger.csv`; runner startup output is
`~/qdc/server.log`. A nonempty result file does not by itself prove the run completed:
check the script exit status, image count and ledger's `infer_done` event.

### Optional: one image manually

Use this **instead of** the batch script when trying a single image. In one board
shell, start the server in the foreground:

```sh
edge-impulse-linux-runner --model-file ~/qdc/model.eim --run-http-server 1337
```

In a second board shell, while keeping the original tunnel open:

```sh
curl --fail-with-body -sS -X POST \
  -F "file=@$HOME/qdc/test-images/daisy.0000.jpg" \
  http://127.0.0.1:1337/api/image
```

Press Ctrl+C in the server shell before running the batch helper on the same port.
CLI 1.25.2 did not expose the `--image` / `--disable-camera` flags from the older
QDC tutorial. HTTP mode worked in the recorded session. The server is a temporary
inference endpoint; do not forward it publicly.

## 5. Retrieve results and end the session

While the tunnel and QDC session are still open, copy the files from a **local**
terminal. Replace the port if your tunnel uses something other than 2222:

```bash
scp -P 2222 arduino@localhost:qdc/results.txt ./results.txt
scp -P 2222 arduino@localhost:qdc/ledger.csv ./ledger.csv
```

Use the session password if prompted. If SCP reports an old host key after QDC
changes boards, follow QDC's generated connection instructions and remove only
the obsolete localhost tunnel entry from your local known_hosts when appropriate.

**Click End Session in QDC after saving the files.** `ledger session_end` only
records a timestamp. Closing SSH does not end the QDC session.

Move the downloaded files into a local `results/` folder, then evaluate:

```bash
node local/evaluate.mjs results/results.txt results/ledger.csv
```

The evaluator prints top-1 accuracy, confusion matrix, wrong predictions, request
latency, and separate runner classification and DSP timings. Missing responses,
invalid JSON, duplicate filenames or unknown labels make it fail rather than
silently dropping samples from the accuracy denominator. No confidence threshold
is applied; ties follow the class order in the JSON response.

**QDC usage and the command ledger are different measurements.** The original
inference session report showed **30 minutes used**. The ledger covered **8.8
minutes** between starting our commands and finishing inference. Check QDC's
session report for allowance usage; do not extrapolate session counts from the
ledger alone. Current QDC access allowances may differ from our 1,000-minute grant.

The article recorded 80/90 correct (88.9%) with int8 and top-1 scoring, versus
87.8% in Studio with float32 and a confidence threshold. These are not controlled
comparisons of quantization quality. Report the model, resize mode and scoring
rule alongside each result. The helper scripts were revised after the manual run;
a clean hardware run of this exact revision remains necessary before claiming
end-to-end verification.

## Files and configuration

| File | Purpose |
| --- | --- |
| `board/00-ledger.sh` | Source into the shell to record phase timestamps. |
| `board/01-setup.sh` | Install Ubuntu dependencies and the pinned Linux CLI. |
| `board/02-connect.sh` | Download a compiled model using project authentication. |
| `board/03-batch-infer.sh` | Own a runner process, classify a folder and save JSON. |
| `local/make-qdc-package.mjs` | Package scripts and your held-out images. |
| `local/evaluate.mjs` | Score saved HTTP responses and summarize timings. |
| `local/results.mjs` | Validated result parser used by the evaluator and tests. |
| `examples/` | Synthetic output to try the evaluator without a QDC session. |

| Variable | Default | Used by |
| --- | --- | --- |
| `LEDGER` | `$HOME/qdc/ledger.csv` | All board helpers |
| `EI_LINUX_VERSION` | `1.25.2` | Setup |
| `EI_API_KEY` | Interactive CLI login if absent | Model download |
| `MODEL` | `$HOME/qdc/model.eim` | Download and batch |
| `OUT` | `$HOME/qdc/results.txt` | Batch |
| `PORT` | `1337` | Batch |
| `SERVER_LOG` | `$HOME/qdc/server.log` | Batch |

## Troubleshooting

- **No images:** put JPEG/PNG files directly in the input folder and rebuild.
- **Cannot find webcams:** use HTTP mode; confirm the installed CLI version.
- **Port already in use:** stop the manually started runner or choose another PORT.
- **Results already exist:** keep the old run and set a different OUT filename.
- **Failed HTTP request:** inspect `server.log` and the saved response; fix the
  cause before retrying with a new OUT. Do not score partial results as a full run.
- **CLI missing after reconnecting:** source `~/.profile`, then rerun setup if needed.
- **Setup errors:** review apt/npm output and available internet, disk and sudo
  permissions. Script success and FastRPC nodes do not prove QNN acceleration.

## Development and GitHub upload

```bash
npm ci --prefix local
npm test --prefix local
npm audit --prefix local --omit=dev
```

Tests use synthetic data and isolated temporary folders. CI checks Node helpers on Windows, macOS and Linux and
checks shell syntax on Linux. These checks do not run real QDC inference.
The offline shell control-flow checks can also be run with
`sh local/test/board-smoke.sh` in Linux, macOS, or Git Bash.

Read [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md) and
[LICENSE](LICENSE). Images, account screenshots, raw run logs, models, packages,
credentials, and installed dependencies are excluded by `.gitignore`.

Before uploading, inspect `git status --short` and `git diff --cached`; the upload
should contain only source, documentation, synthetic examples, tests and lockfile.
If uploading through GitHub's browser, use the prepared source ZIP: GitHub's web
upload does not apply this folder's `.gitignore` to files you drag into it.

## References

- [Edge Impulse VENTUNO Q setup](https://docs.edgeimpulse.com/hardware/boards/arduino-ventuno-q)
- [Edge Impulse QDC tutorial](https://docs.edgeimpulse.com/tutorials/topics/inference/run-qualcomm-device-cloud)
- [Qualcomm Device Cloud](https://qdc.qualcomm.com)
- [Arduino VENTUNO Q](https://docs.arduino.cc/hardware/ventuno-q/)
