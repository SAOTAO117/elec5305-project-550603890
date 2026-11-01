function c = experimentSettings(windowLength)
% Keep the smoothing time constant fixed when changing the analysis hop.
if nargin == 0, windowLength = 512; end
assert(ismember(windowLength,[256 512]),"Use a 16 ms or 32 ms window.");
c.SampleRate = 16000;
c.WindowLength = windowLength;
c.HopLength = windowLength/2;
c.OverlapLength = windowLength/2;
c.FFTLength = 512;
c.Window = sqrt(hann(windowLength,"periodic"));
c.NoiseSmoothing = 0.8^(c.HopLength/256);
c.GainFloor = 0.05;
c.CalibrationSeconds = 0.5;
c.InputSNRdB = [-5 0 5 10];
c.NoiseRepeats = 2;
c.RandomSeed = 5305;
end
