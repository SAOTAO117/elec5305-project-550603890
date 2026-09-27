function result = wienerFilter(noisy,clean,noise,prefixSamples,c)
% Apply one STFT Wiener gain and decompose the output into known components.
[Y,meta]=analysis(noisy,c);
[S,cleanMeta]=analysis(clean,c); [N,noiseMeta]=analysis(noise,c);
assert(isequal(meta.Centres,cleanMeta.Centres,noiseMeta.Centres),"STFT frame mismatch.");
halfWindow=c.WindowLength/2;
calibration=meta.Centres-halfWindow>=0 & meta.Centres+halfWindow<=prefixSamples;
assert(nnz(calibration)>=2,"The noise-only calibration interval is too short.");
powerY=abs(Y).^2;
noisePSD=mean(powerY(:,calibration),2);
powerFloor=max(max(powerY(:))*1e-12,realmin);
smoothed=noisePSD; gain=zeros(size(Y));
for frame=1:size(Y,2)
    smoothed=c.NoiseSmoothing*smoothed+(1-c.NoiseSmoothing)*powerY(:,frame);
    speechPSD=max(smoothed-noisePSD,0);
    gain(:,frame)=max(c.GainFloor,speechPSD./max(speechPSD+noisePSD,powerFloor));
end
result.Clean=clean; result.Noise=noise; result.Noisy=noisy;
result.Enhanced=synthesis(gain.*Y,meta,c);
result.SpeechComponent=synthesis(gain.*S,meta,c);
result.NoiseComponent=synthesis(gain.*N,meta,c);
reconstructed=synthesis(Y,meta,c);
result.ReconstructionError=norm(reconstructed-noisy)/max(norm(noisy),realmin);
result.DecompositionError=norm(result.Enhanced-result.SpeechComponent-result.NoiseComponent) ...
    /max(norm(result.Enhanced),realmin);
assert(result.ReconstructionError<1e-10 && result.DecompositionError<1e-10, ...
    "STFT reconstruction or component decomposition failed.");
result.Y=Y; result.S=S; result.N=N; result.Gain=gain;
result.Centres=meta.Centres; result.Frequency=meta.Frequency;
result.PrefixSamples=prefixSamples;
end

function [s,meta] = analysis(x,c)
left=c.WindowLength/2;
frameIntervals=max(1,ceil((left+numel(x)-c.OverlapLength)/c.HopLength));
paddedLength=c.OverlapLength+frameIntervals*c.HopLength;
right=paddedLength-left-numel(x);
padded=[zeros(left,1);x;zeros(right,1)];
[s,frequency,time]=stft(padded,c.SampleRate,Window=c.Window, ...
    OverlapLength=c.OverlapLength,FFTLength=c.FFTLength,FrequencyRange="twosided");
meta.Centres=round(time*c.SampleRate)-left;
meta.Frequency=frequency(1:c.FFTLength/2+1);
meta.Left=left; meta.Length=numel(x); meta.PaddedLength=paddedLength;
end

function x = synthesis(s,meta,c)
padded=istft(s,c.SampleRate,Window=c.Window,OverlapLength=c.OverlapLength, ...
    FFTLength=c.FFTLength,FrequencyRange="twosided",Method="wola", ...
    ConjugateSymmetric=true);
assert(numel(padded)==meta.PaddedLength,"Unexpected ISTFT output length.");
x=padded(meta.Left+(1:meta.Length));
end
