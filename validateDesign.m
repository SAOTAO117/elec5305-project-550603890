function validateDesign
% Validate transform, gain and measurement calculations.
stream=RandStream("mt19937ar",Seed=5305);
for windowLength=[256 512]
    c=experimentSettings(windowLength);
    prefix=round(c.CalibrationSeconds*c.SampleRate);
    for length=[511 16003]
        speech=0.1*randn(stream,length,1);
        clean=[zeros(prefix,1);speech];
        noise=0.1*randn(stream,numel(clean),1);
        noisy=clean+noise;
        r=wienerFilter(noisy,clean,noise,prefix,c);
        assert(numel(r.Enhanced)==numel(noisy));
        assert(all(r.Gain(:)>=c.GainFloor & r.Gain(:)<=1));
        alternate=wienerFilter(noisy,0.4*clean,noisy-0.4*clean,prefix,c);
        assert(isequal(r.Gain,alternate.Gain),"Gain depends on clean reference.");
        unity=c; unity.GainFloor=1;
        u=wienerFilter(noisy,clean,noise,prefix,unity);
        assert(norm(u.Enhanced-noisy)/norm(noisy)<1e-10);
        % Include a one-sample phone to exercise missing-frame handling.
        labels=table([0;1],[1;length],["T";"IY"],["stops_affricates";"vowels"], ...
            VariableNames=["Start","End","Phone","Class"]);
        [phones,globalResult]=phoneMetrics(u,labels,0,c);
        assert(max(abs(phones.SpeechRetentiondB))<1e-10);
        assert(max(abs(phones.ResidualNoiseRatiodB))<1e-10);
        assert(abs(globalResult.DeltaErrorSNRdB)<1e-10);
        assert(sum(phones.FrameCount)==sum(r.Centres>=prefix & r.Centres<prefix+length));
        assert(all(isnan(phones.MeanGain(phones.FrameCount==0))));
        centres=r.Centres-prefix;
        frames=centres>=1 & centres<length;
        allEnergy=sum(abs(u.S(:,frames)).^2,"all");
        half=c.FFTLength/2+1;
        weights=2*ones(half,1); weights([1 end])=1;
        oneEnergy=sum(weights.*abs(u.S(1:half,frames)).^2,"all");
        assert(abs(allEnergy-oneEnergy)/allEnergy<1e-10);
    end
end
short=experimentSettings(256); base=experimentSettings(512);
assert(abs(log(short.NoiseSmoothing)/short.HopLength- ...
    log(base.NoiseSmoothing)/base.HopLength)<1e-12);
stats=pairedStats(ones(10,1));
assert(stats.MeanDifference==1 && stats.Lower95==1 && stats.Upper95==1);
fprintf("Design validation passed: reconstruction, decomposition, gain independence,\n");
fprintf("unity gain, phone coverage, one-sided energy and matched smoothing.\n");
end
