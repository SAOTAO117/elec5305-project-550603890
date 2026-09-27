function [segments,globalMetrics] = phoneMetrics(result,labels,inputSNRdB,c)
% Calculate phone-level preservation and whole-utterance reference metrics.
prefix=result.PrefixSamples; keep=prefix+(1:labels.End(end));
clean=result.Clean(keep); noisy=result.Noisy(keep); enhanced=result.Enhanced(keep);
speechComponent=result.SpeechComponent(keep); noiseIn=result.Noise(keep);
noiseOut=result.NoiseComponent(keep);
centres=result.Centres-prefix;
frequency=result.Frequency; oneSided=c.FFTLength/2+1;
S=result.S(1:oneSided,:); Y=result.Y(1:oneSided,:);
G=result.Gain(1:oneSided,:); filteredSpeech=G.*S; filteredMixture=G.*Y;
weights=2*ones(oneSided,1); weights([1 end])=1;
bands={true(oneSided,1),frequency<1000,frequency>=1000 & frequency<4000,frequency>=4000};
spectralFloor=max(max(abs(S(:)))*1e-3,realmin);
rows=cell(height(labels),1);
for index=1:height(labels)
    sampleIndex=labels.Start(index)+1:labels.End(index);
    frameIndex=centres>=labels.Start(index) & centres<labels.End(index);
    row=struct("Segment",index,"Phone",labels.Phone(index),"Class",labels.Class(index), ...
        "StartSeconds",labels.Start(index)/c.SampleRate, ...
        "EndSeconds",labels.End(index)/c.SampleRate,"FrameCount",nnz(frameIndex), ...
        "MeanGain",NaN,"GainBelow1k",NaN,"Gain1to4k",NaN,"Gain4to8k",NaN, ...
        "SpeechRetentiondB",NaN,"HighFrequencyRetentiondB",NaN, ...
        "ResidualNoiseRatiodB",ratioDb(sum(noiseOut(sampleIndex).^2),sum(noiseIn(sampleIndex).^2)), ...
        "MixtureLSDdB",NaN,"SpeechLSDdB",NaN,"InputErrorSNRdB",NaN, ...
        "OutputErrorSNRdB",NaN,"DeltaErrorSNRdB",NaN);
    speechEnergy=sum(clean(sampleIndex).^2);
    isSpeech=labels.Class(index)~="silence" && speechEnergy>1e-12*sum(clean.^2);
    if isSpeech
        row.InputErrorSNRdB=errorSnr(clean(sampleIndex),noisy(sampleIndex)-clean(sampleIndex));
        row.OutputErrorSNRdB=errorSnr(clean(sampleIndex),enhanced(sampleIndex)-clean(sampleIndex));
        row.DeltaErrorSNRdB=row.OutputErrorSNRdB-row.InputErrorSNRdB;
    end
    if any(frameIndex)
        names=["MeanGain","GainBelow1k","Gain1to4k","Gain4to8k"];
        for band=1:numel(bands)
            row.(names(band))=mean(G(bands{band},frameIndex),"all");
        end
        if isSpeech
            original=abs(S(:,frameIndex)).^2;
            retained=abs(filteredSpeech(:,frameIndex)).^2;
            originalEnergy=sum(weights.*original,"all");
            row.SpeechRetentiondB=ratioDb(sum(weights.*retained,"all"),originalEnergy);
            high=bands{4}; highEnergy=sum(weights(high).*original(high,:),"all");
            if highEnergy>max(originalEnergy*1e-10,realmin)
                row.HighFrequencyRetentiondB=ratioDb( ...
                    sum(weights(high).*retained(high,:),"all"),highEnergy);
            end
            reference=20*log10(max(abs(S(:,frameIndex)),spectralFloor));
            mixtureDifference=20*log10(max(abs(filteredMixture(:,frameIndex)),spectralFloor))-reference;
            speechDifference=20*log10(max(abs(filteredSpeech(:,frameIndex)),spectralFloor))-reference;
            row.MixtureLSDdB=mean(sqrt(mean(mixtureDifference.^2,1)));
            row.SpeechLSDdB=mean(sqrt(mean(speechDifference.^2,1)));
        end
    end
    rows{index}=row;
end
segments=struct2table(vertcat(rows{:}));
inputErrorSNR=errorSnr(clean,noisy-clean);
outputErrorSNR=errorSnr(clean,enhanced-clean);
inputSTOI=NaN; outputSTOI=NaN;
if exist("stoi","file")==2 && numel(clean)>=c.SampleRate
    inputSTOI=stoi(noisy,clean,c.SampleRate);
    outputSTOI=stoi(enhanced,clean,c.SampleRate);
end
globalMetrics=table(inputSNRdB,inputErrorSNR,outputErrorSNR, ...
    outputErrorSNR-inputErrorSNR,inputSTOI,outputSTOI, ...
    result.ReconstructionError,result.DecompositionError, ...
    VariableNames=["ActiveInputSNRdB","InputErrorSNRdB","OutputErrorSNRdB", ...
    "DeltaErrorSNRdB","InputSTOI","OutputSTOI","ReconstructionError","DecompositionError"]);
end

function value = errorSnr(signal,errorSignal)
if sum(signal.^2)==0, value=NaN;
else, value=ratioDb(sum(signal.^2),sum(errorSignal.^2)); end
end

function value = ratioDb(numerator,denominator)
if numerator==0, value=NaN;
else, value=10*(log10(max(numerator,realmin))-log10(max(denominator,realmin))); end
end
