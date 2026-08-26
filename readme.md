# ELEC5305 Project Proposal

## 1. Project Title

Wiener Filtering for Speech Enhancement

## 2. Student Information

Full Name: Weitao Shi  
Student ID (SID): 550603890  
GitHub Username: SAOTAO117  
GitHub Project Link: [(https://saotao117.github.io/elec5305-project-550603890/)]

## 3. Project Overview

Speech recordings often contain unwanted background noise. Traffic, fans and other sounds in the surrounding environment may be recorded together with the speaker. When the noise becomes noticeable, the speech can be harder to understand. This is especially a problem when the speech and noise appear at the same time and share similar frequency components.

This project looks at whether Wiener filtering can improve a noisy speech recording. The filtering will be implemented in MATLAB and tested on speech mixed with background noise. The recording before and after filtering will be compared. The main concern is not only whether the noise becomes weaker, but also whether the speech remains clear after processing. This comparison will be used to examine the practical effect of Wiener filtering on speech affected by background noise.

## 4. Background and Motivation

Removing noise from a speech recording can be difficult because the speech and background noise exist in the same signal. The noise may also change during the recording, so removing a fixed frequency range is not always suitable. If speech and noise occupy some of the same frequencies, removing those frequencies may also remove useful parts of the speech.

Wiener filtering is one method used for speech enhancement. The filter uses information about the signal and noise to decide how much filtering is needed. Instead of applying the same amount of reduction to the entire signal, the Wiener filter changes its response according to the estimated speech and noise components. Noise estimation is therefore an important part of the process. Jaiswal et al. [1] studied Wiener filtering for single-channel speech under stationary and non-stationary noise conditions and showed the importance of noise estimation in the enhancement process. Their results also showed that inaccurate noise estimation can affect the quality of the processed speech.

Speech also changes continuously during a recording. For this reason, speech enhancement can be carried out using short sections of the signal rather than processing the complete recording as one section. Each short section can be represented in the frequency domain, allowing the frequency components of the speech and noise to be examined. Recent Wiener-based speech enhancement research also uses this type of short-time frequency-domain processing.

Wiener-based methods can also be found in more recent speech enhancement research. Yechuri and Vanambathina [2] applied an adaptive Wiener gain to speech enhancement. Xiang et al. [3] studied Wiener gain for speech signals affected by noise. These studies use more advanced processing, while the current project only considers the basic Wiener filtering process.

A basic Wiener filter will be used without adding other enhancement methods. The purpose is to see how much the background noise changes after filtering and whether the speech is affected at the same time. Keeping the processing simple also makes it easier to relate changes in the output recording directly to the Wiener filter.

## 5. Proposed Methodology

A speech recording with background noise will be used for the experiment. Before filtering, the recording will be imported into MATLAB and examined using its waveform and spectrogram. Listening to the original recording will provide another reference for the later comparison. The waveform gives an initial view of the signal amplitude over time, while the spectrogram shows how its frequency content changes during the recording.

The recording will then be separated into short sections for processing. Speech changes over time, so working with shorter sections makes it possible to examine its changing frequency content. A frequency representation will be obtained for each section before Wiener filtering is applied. This type of frame-based processing is commonly used for Wiener speech enhancement because the characteristics of speech and noise can change throughout a recording [1].

Background noise will be estimated from the recording and this estimate will be used in the Wiener filter. The filter will reduce parts of the signal where the estimated noise has a stronger effect. Where speech is stronger compared with the estimated noise, more of the original signal can be retained. The aim is therefore not to remove every low-level component, but to reduce the components that are more likely to be caused by background noise.

Once the filtering is complete, the processed sections will be joined to form the enhanced speech recording. Both recordings can then be played under the same conditions. Listening to the original and filtered recordings will help identify changes in the background noise as well as any change in the speech.

Waveforms and spectrograms of both recordings will also be compared. The waveforms provide a time-domain view of the signals, while the spectrograms make it possible to examine their frequency content over time. Jaiswal et al. [1] also presented time-domain signals and spectrograms when examining Wiener-filtered speech. The audio and plots will be considered together when evaluating the filtering result.

## 6. Expected Outcomes

Less background noise is expected in the processed recording. The speech should remain understandable, although some change in the voice may occur because speech and noise can overlap in the same parts of the signal.

Listening to the original and processed recordings will provide a direct comparison of the filtering effect. Changes may also be visible in the waveform and spectrogram, especially where the original recording contains stronger background noise. The spectrogram is expected to make some of these changes easier to observe because the frequency content can be viewed over time.

Complete removal of the noise is not expected. Removing too much of the signal could also affect the speech. The result will therefore depend on whether the filter reduces the unwanted noise without causing a large loss of speech information.

## 7. Timeline

| Weeks | Task |
| --- | --- |
| 1-2 | Select the project topic, define the speech enhancement problem, and determine the project objectives. |
| 3-5 | Review the Wiener filtering method, prepare the clean speech and background noise recordings, and complete the initial signal analysis. |
| 6-9 | Develop the Wiener filtering code in MATLAB and test the speech processing. |
| 10-11 | Compare the original and filtered speech using listening, waveforms and spectrograms, and analyse the filtering performance. |
| 12-13 | Analyse the results, finalise the MATLAB program and complete the project report. |

## 8. References

[1] R. K. Jaiswal, S. R. Yeduri, and L. R. Cenkeramaddi, "Single-channel speech enhancement using implicit Wiener filter for high-quality speech communication," *International Journal of Speech Technology*, vol. 25, pp. 745-758, 2022, doi: 10.1007/s10772-022-09987-4.

[2] S. Yechuri and S. Vanambathina, "Single channel speech enhancement using iterative constrained NMF based adaptive Wiener gain," *Multimedia Tools and Applications*, vol. 83, pp. 26233-26254, 2024, doi: 10.1007/s11042-023-16480-w.

[3] Q. Xiang, J. Chen, J. Benesty, T. Lei, and C. Pan, "Design of the Wiener gain in noisy and reverberant environments," *Applied Acoustics*, vol. 231, Art. no. 110491, 2025, doi: 10.1016/j.apacoust.2024.110491.

