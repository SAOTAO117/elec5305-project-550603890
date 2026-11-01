# Experimental Method

## Research question

Does STFT Wiener filtering preserve broad phonetic classes unequally, and can
whole-utterance error-SNR improvement coexist with loss of desired speech energy?
The study evaluates one filter on ten utterances from ten speakers, three noise
recordings, four SNR levels and two noise excerpts: 240 mixtures, with speaker
as the independent sampling unit.

## Data and labels

Speech and phone boundaries are from [LibriSpeech Segment](https://huggingface.co/datasets/changelinglab/librispeech-segment),
a derivative corpus with existing alignments. Utterance IDs, transcripts and source are recorded in
`data/corpusSelection.csv`; audio and label paths are in `data/speechManifest.csv`.
Label validation checks continuous coverage, positive duration, known symbols
and class assignments.

| Class | Phone labels |
| --- | --- |
| Vowels | AA AE AH AO AW AY EH ER EY IH IY OW OY UH UW |
| Nasals and approximants | M N NG L R W Y |
| Fricatives | F V TH DH S Z SH ZH HH |
| Stops and affricates | P B T D K G CH JH |
| Silence | [SIL] |

The fricative group includes voiced fricatives and HH. Stop labels cover the
full segment, including more than the burst alone.
Figure labels use the supplied phone codes: IY for the example vowel, S for
the fricative, N for the nasal and D for the stop; [SIL] indicates silence.

The noise files are channel-one excerpts derived from
[DEMAND](https://zenodo.org/records/1227121): DKITCHEN, PCAFETER and STRAFFIC.
All signals are included as 16 kHz mono files.

## Mixtures and Wiener estimation

Noise is scaled over samples whose labels are not silence:

`alpha = sqrt(sum(s_active.^2) / (sum(v_active.^2) * 10^(SNR/10)))`.

The target values are -5, 0, 5 and 10 dB. A 0.5 s noise-only prefix immediately
precedes each utterance. The same noise crop is reused across SNR levels; a
fixed per-utterance/noise/repeat seed selects the crop. `global_results.csv`
records its one-based start sample and scale. The two random crops may overlap.

The baseline uses a 512-sample square-root periodic Hann window, a 256-sample
hop, a 512-point FFT and two-sided spectra. The noise PSD is the mean of
`abs(Y).^2` over windows wholly contained in the prefix; it is fixed afterwards.
Mixture power is smoothed recursively with coefficient 0.8. Speech power is
estimated as the positive part of smoothed mixture power minus the noise PSD.
The real amplitude gain is `max(0.05, P_s / max(P_s + P_n, floor))`, where the
floor is the greater of `1e-12 * max(abs(Y).^2)` and `realmin`.
The gain multiplies the complex mixture STFT, retaining its phase.

For uncorrelated speech and noise, minimizing the expected squared error
`E[abs(S-GY)^2]` for a real gain in one time-frequency bin gives
`G = P_s/(P_s+P_n)`. This objective has no explicit phonetic-class or
intelligibility term. The implementation estimates the powers and applies a
gain floor, so the theoretical optimum is only approximated.

MATLAB [stft](https://www.mathworks.com/help/signal/ref/stft.html) and
[istft](https://www.mathworks.com/help/signal/ref/istft.html) perform the transforms.
The inverse uses the same window with weighted overlap-add. Boundary padding is
removed before measurement. Processing is offline.

Clean speech and noise are used to evaluate the fixed gain, never to estimate
it. Applying that gain to their STFTs separately produces speech and noise
components whose sum equals the enhanced mixture to numerical precision.

## Measurements

All whole-utterance metrics exclude the prefix but include labelled silence.
The target input SNR uses active speech only, so it can differ from the
whole-utterance input error SNR.

| Measurement | Definition and interpretation |
| --- | --- |
| Error SNR | `10 log10(sum(s.^2)/sum((output-s).^2))`; output error includes residual noise and speech modification |
| Segmental error SNR | The same expression on each exact labelled sample interval; class summaries average phone scores in dB |
| SpeechRetentiondB | Energy of the filtered clean component divided by original clean energy, on the exact phone sample interval |
| ResidualNoiseRatiodB | Filtered-noise energy divided by input-noise energy on that same sample interval |
| MeanGain | Unweighted average amplitude gain over bins and frames whose centres lie in the phone |
| WeightedGain | Amplitude gain averaged with clean spectral-energy weights |
| FrameSpeechRetentiondB | Filtered-clean STFT energy divided by original STFT energy in centre-assigned frames; retained as a boundary-sensitivity diagnostic |
| HighFrequencyRetentiondB | Frame-based energy ratio for 4-8 kHz |
| MixtureLSDdB | Frame-average RMS log-magnitude difference between enhanced mixture and clean speech |
| SpeechLSDdB | The corresponding difference for the filtered clean component, isolating gain-induced modification |
| BoundaryFrameFraction | Fraction of centre-assigned windows that extend outside the phone interval |
| STOI | Whole-utterance objective intelligibility prediction |

More negative retention ratios indicate greater attenuation. Time-domain
retention can occasionally exceed 0 dB on a short segment because overlap-add
redistributes energy across its boundaries; it is not clipped. Frame energy
ratios use one-sided weights of two except at DC and Nyquist. The log-magnitude
floor is `1e-3` times the largest clean STFT magnitude for that utterance.
Speech energy below `1e-12` of utterance energy is excluded from speech metrics.
High-frequency ratios require band energy above `1e-10` of total weighted clean
STFT energy across the phone's assigned frames.
Silence is excluded from speech-retention and distortion comparisons.

WeightedGain averages amplitude gain, while frame-energy retention averages
squared gain. Neither is identical to retention on an exact interval after
overlap-add synthesis.

Each frame is assigned once by its centre. A phone with no frame receives NaN
for spectral metrics; its time-domain metrics remain available. Valid speaker
counts accompany every class metric. Time-domain retention is the primary
speech/noise trade-off measurement.

## Aggregation and uncertainty

Repeat measurements are first averaged within each phone token. Tokens are then
averaged within each speaker, noise, SNR and class. Finally speakers receive
equal weight. There is one utterance per speaker in this study. Pooled summaries
give equal weight to noise/SNR conditions within speaker before averaging
speakers. Means of dB ratios are reported as such, not as pooled energy ratios.

SDs describe variation between speaker means. Class contrasts pair each
speaker's class mean with that speaker's vowel mean in the same condition.
Bootstrap intervals resample the ten paired speaker differences 10,000 times
with seed 5305. These are exploratory percentile intervals, without adjustment
for multiple comparisons.

## Window-length experiment

Short consonants motivated a paired 16 ms versus 32 ms comparison. The shorter
window uses 256 samples and a 128-sample hop, retaining 50% overlap and a
512-point FFT. Zero padding maintains a common frequency grid, not equal true
frequency resolution. The smoothing coefficient is `0.8^(128/256)` so its
time constant matches the baseline. The gain floor, calibration duration,
speech, crop locations, noise scaling and labels are identical.

The primary comparison uses exact sample-interval speech retention, global
error SNR, STOI and residual noise. Frame-boundary crossing is also reported.
The reported change is 16 ms minus 32 ms. A positive speech-retention
difference means less attenuation.
Changing the window also changes true frequency resolution and the sequence of
power observations. This comparison cannot isolate boundary mixing alone.

## Validation and limits

`validateDesign` checks unity-gain reconstruction, decomposition, gain
independence from reference components, gain limits, missing-frame handling,
one-sided energy weights and equal smoothing time constants. Every mixture
also checks calibrated active SNR and reconstruction/decomposition errors.

The ten utterances form a convenience sample, and the supplied alignments
have not been manually reannotated. Broad classes combine varied sounds;
duration, energy and noise overlap can affect their comparison. The fixed
noise estimate can become inaccurate as the noise changes. Energy ratios and
STOI do not establish perceptual or linguistic losses without listening tests.

## Observed results

Both configurations completed 240 mixtures. The baseline contains 549 labelled
tokens, including 43 silence segments, measured under 24 conditions per token
(13,176 rows). Every token receives at least one frame. Forty of the 506 speech
tokens have no 32 ms frame wholly inside their boundaries. All 240 mixtures
pass active-SNR calibration and component-decomposition checks. The largest
baseline reconstruction error is `2.7e-16`.

The baseline improves whole-utterance error SNR by a mean 6.18 dB. Mean STOI
changes from 0.8432 to 0.8385. Thus, improved error SNR does not imply an
improved objective intelligibility score in these conditions.

The following summaries first average conditions within each speaker, then
report the mean and SD over ten speakers. Speech and noise ratios use the same
exact phone intervals. Frame-based frequency measurements remain separate.

| Class | Speech retention, dB | Noise retention, dB | Unweighted gain | Speech-energy-weighted gain |
| --- | ---: | ---: | ---: | ---: |
| Vowels | -1.24 +/- 0.31 | -8.67 +/- 1.88 | 0.450 | 0.875 |
| Nasals / approximants | -1.48 +/- 0.51 | -8.84 +/- 2.13 | 0.424 | 0.851 |
| Fricatives | -2.53 +/- 1.14 | -9.02 +/- 1.90 | 0.465 | 0.749 |
| Stops / affricates | -2.51 +/- 0.85 | -9.01 +/- 2.11 | 0.422 | 0.742 |

Fricatives have a slightly higher unweighted gain than vowels but a lower
speech-energy-weighted gain and more negative speech retention. Averaging gain
uniformly across bins therefore does not determine retained speech energy.
The pooled difference is descriptive; the condition-specific paired estimates
and intervals are in `results/tables/class_contrasts.csv`.

Metric rankings are not interchangeable. For example, speech-component LSD is
4.43 dB for vowels and 3.74 dB for fricatives, whereas mixture LSD is 6.45 and
6.82 dB, respectively. LSD weights log-spectral errors across frequency bins;
energy retention emphasizes the bins carrying clean speech energy. These
results do not support a claim that consonants are worst on every measure.

| Paired change, 16 ms minus 32 ms | Mean | Exploratory 95% interval |
| --- | ---: | ---: |
| Whole-utterance error-SNR improvement, dB | +0.063 | [-0.043, +0.166] |
| Whole-utterance STOI | -0.0093 | [-0.0110, -0.0077] |
| Whole-utterance noise retention, dB | -0.362 | [-0.491, -0.249] |
| Vowel speech retention, dB | -0.477 | [-0.561, -0.396] |
| Nasal / approximant speech retention, dB | -0.609 | [-0.768, -0.474] |
| Fricative speech retention, dB | -0.593 | [-0.711, -0.486] |
| Stop / affricate speech retention, dB | -0.628 | [-0.767, -0.484] |

The mean fraction of crossing frames falls from approximately 42-46% to
19-21%, depending on class. The shorter window nevertheless retains less
desired speech and yields a lower STOI score; its small error-SNR difference
has an interval containing zero. It suppresses somewhat more noise at the
cost of more speech attenuation. The 32 ms baseline is retained. This is a
measured trade-off, not evidence that 32 ms is universally optimal.

The numerical source is `results/window_comparison/window_comparison.csv`.
