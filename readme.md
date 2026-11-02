# ELEC5305 Project

## Global Noise Reduction versus Phonetic Preservation in Wiener Speech Enhancement

This repository contains the MATLAB code, audio and labels for my ELEC5305
project. The experiment applies an STFT Wiener filter to speech mixed with three
environmental noises, then compares whole-utterance measurements with results
for four phoneme groups.

[Project site](https://saotao117.github.io/elec5305-project-550603890/) ·
[Project report](report/ELEC5305_Project_Report_550603890.pdf) ·
[Video](https://saotao117.github.io/elec5305-project-550603890/#presentation) ·
[Slides](presentation/ELEC5305_Presentation_550603890.pptx)

## Project files

- `main.m` runs the experiment.
- `wienerFilter.m` applies the Wiener filter.
- `phoneMetrics.m` calculates the measurements.
- `loadPhoneLabels.m` reads the phoneme labels.
- `experimentSettings.m` defines the filter and experiment parameters.
- `analyseResults.m` produces speaker-level statistics and paired class comparisons.
- `plotExample.m` exports individual example plots and audio.
- `compareWindows.m` runs the paired 32 ms and 16 ms experiments.
- `validateDesign.m` checks the signal processing and metric calculations.
- `pairedStats.m` calculates speaker-level paired bootstrap intervals.
- `data/speech` contains ten speech recordings.
- `data/noise` contains the three noise recordings.
- `data/labels` contains the phoneme labels.
- `results/tables` contains the result tables.
- `results/figures` contains individual plots with descriptive filenames.
- `results/audio` contains the clean, noisy and enhanced examples.
- `results/window_comparison` contains the 16 ms results and paired comparison with the 32 ms baseline.
- `report` contains the project report.
- `presentation` contains the presentation slides.
- `video` contains the recorded presentation.

## Requirements

- MATLAB (tested with R2025b)
- Signal Processing Toolbox

Audio Toolbox is required to reproduce the STOI results. Without it, those
columns are NaN; the remaining measurements are still calculated.

## Running the program

Download the repository using **Code → Download ZIP**, extract it, open the
project folder in MATLAB and run:

```matlab
main
```

The program uses the included data and writes the results to the three folders
inside `results`.

For the numerical checks and the complete window-length comparison, run:

```matlab
validateDesign
compareWindows
```

`compareWindows` reruns the 32 ms baseline and the 16 ms comparison on identical
mixtures. The shorter-window results are stored in `results/window_comparison`.
The comparison is a sensitivity experiment, not a filter selected on test scores.

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
- `class_summary.csv` contains class means, between-speaker SDs and valid counts.
- `speaker_results.csv` and `global_speaker_results.csv` retain the speaker means.
- `global_summary.csv` reports global metrics after averaging noise excerpts within speaker.
- `class_contrasts.csv` compares each consonant group with vowels within speaker.
- `pooled_class_summary.csv` reports component and frequency-band measurements.
- `label_coverage.csv` counts segments with missing or boundary-crossing frames.
- `configuration.csv` records parameters and the MATLAB version.
- Global and phone-interval error SNR, speech retention, gain and spectral distortion are plotted
  separately for each noise. Error bars show SD across speakers, not 240
  independent samples. Spectrograms share one colour scale; the gain map includes
  a time-aligned phonetic-class strip.
- `window_comparison/window_comparison.csv` reports paired changes from 32 ms
  to 16 ms, including exploratory 95% speaker-bootstrap intervals.
- The three WAV files provide one clean, noisy and enhanced example.

The project page is available at
[https://saotao117.github.io/elec5305-project-550603890/](https://saotao117.github.io/elec5305-project-550603890/).

## Data sources

Speech and phoneme labels are from
[LibriSpeech Segment](https://huggingface.co/datasets/changelinglab/librispeech-segment).
The sample uses the first eligible utterance from each of ten different speakers
in the `dev.clean` split. Eligible recordings last 3–8 seconds, contain all four
speech classes and silence, and have known phone symbols and continuous timing
labels. The selected IDs and transcripts are in `data/corpusSelection.csv`.

`data/speechManifest.csv` pairs each recording with its label CSV. Label columns
are `start_s`, `end_s`, `phone` and `class`. Times are seconds from the beginning
of the audio; intervals include the start and exclude the end. `loadPhoneLabels`
rounds boundaries to samples and checks complete, continuous coverage and the
class assignments listed in [Experimental Method](design.md). These are supplied
alignments, not manually reannotated labels. No aligner or additional download is
needed to run the included experiment.

The environmental noise recordings are from
[DEMAND](https://zenodo.org/records/1227121).
`data/noiseManifest.csv` specifies the three included mono recordings and their
channel. Each run records the crop start and scaling in `global_results.csv`.
The example WAV files use a common playback scale to avoid clipping; numerical
measurements are calculated before that scaling.

See [Experimental Method](design.md) for metric definitions, label grouping,
aggregation, the window comparison and limitations. MATLAB performs STFT and
inverse STFT; gain estimation and phonetic evaluation are implemented here.

## Research references

- Loizou, [Speech Enhancement: Theory and Practice](https://doi.org/10.1201/b14529): Wiener estimation and its assumptions.
- Kim and Loizou, [Gain-induced speech distortions](https://doi.org/10.1121/1.3619790): the distinction between attenuation and intelligibility.
- Monir, Magron and Serizel, [A phoneme-scale assessment of multichannel speech enhancement algorithms](https://doi.org/10.1177/23312165241292205): motivation for phoneme-level evaluation.
- Kong, Mullangi and Kokkinakis, [Classification of fricative consonants for speech enhancement in hearing devices](https://doi.org/10.1371/journal.pone.0095001): fricative spectral features.
- Shadle and colleagues, [Refining and extending measures for fricative spectra](https://doi.org/10.1121/10.0021075): frequency-dependent acoustic measurements.
- Taal and colleagues, [An algorithm for intelligibility prediction of time-frequency weighted noisy speech](https://doi.org/10.1109/TASL.2011.2114881): STOI as an utterance-level reference.
