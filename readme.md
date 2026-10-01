# ELEC5305 Project

## Global Noise Reduction versus Phonetic Preservation in Wiener Speech Enhancement

This repository contains the MATLAB code, audio and labels for my ELEC5305
project. The experiment applies an STFT Wiener filter to speech mixed with three
environmental noises, then compares whole-utterance measurements with results
for four phoneme groups.

## Project files

- `main.m` runs the experiment.
- `wienerFilter.m` applies the Wiener filter.
- `phoneMetrics.m` calculates the measurements.
- `loadPhoneLabels.m` reads the phoneme labels.
- `plotExample.m` creates the three example-analysis figures and audio.
- `data/speech` contains ten speech recordings.
- `data/noise` contains the three noise recordings.
- `data/labels` contains the phoneme labels.
- `results/tables` contains the result tables.
- `results/figures` contains the seven report figures.
- `results/audio` contains the clean, noisy and enhanced examples.

## Requirements

- MATLAB (tested with R2025b)
- Signal Processing Toolbox

Audio Toolbox is not required unless STOI is used.

## Running the program

Open the project folder in MATLAB and run:

```matlab
main
```

The program uses the included data and writes the results to the three folders
inside `results`.

## Experiment setup

- 10 speakers
- 3 environmental noises: DKITCHEN, PCAFETER and STRAFFIC
- Input SNR values of -5, 0, 5 and 10 dB
- 2 noise sections for each speech and noise combination
- 240 test conditions in total

The phoneme labels are grouped as vowels, nasals/approximants, fricatives and
stops/affricates. Silence is also included when the Wiener gain is compared.

## Included results

The output from my test run is already included in `results`:

- `global_results.csv` contains one row for each test condition.
- `phone_results.csv` contains the result for each labelled phoneme segment.
- `class_summary.csv` contains the average result for each phoneme group.
- Figures 1 to 7 compare global and phoneme-level results, Wiener gain, speech
  retention, spectral distortion and one aligned time-frequency example.
- The three WAV files provide one clean, noisy and enhanced example.

The project page is available at
[https://saotao117.github.io/elec5305-project-550603890/](https://saotao117.github.io/elec5305-project-550603890/).

## Data sources

Speech and phoneme labels are from
[LibriSpeech Segment](https://huggingface.co/datasets/changelinglab/librispeech-segment).
The environmental noise recordings are from
[DEMAND](https://zenodo.org/records/1227121).
