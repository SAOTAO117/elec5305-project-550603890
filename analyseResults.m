function analyseResults(phones,globalResults,speakers,tablesFolder,figuresFolder,makeFigures)
% Report variation across speakers and contrasts within the same speakers.
globalResults.DeltaSTOI = globalResults.OutputSTOI-globalResults.InputSTOI;
metrics = ["InputErrorSNRdB","OutputErrorSNRdB","DeltaErrorSNRdB", ...
    "InputSTOI","OutputSTOI","DeltaSTOI","SpeechRetentiondB","ResidualNoiseRatiodB"];
[group,globalSpeakers] = findgroups(globalResults(:,["SpeakerId","Noise","SNRdB"]));
for metric = metrics
    globalSpeakers.(metric) = splitapply(@finiteMean,globalResults.(metric),group);
end
[group,summary] = findgroups(globalSpeakers(:,["Noise","SNRdB"]));
for metric = metrics
    summary.(metric+"Mean") = splitapply(@finiteMean,globalSpeakers.(metric),group);
    summary.(metric+"SD") = splitapply(@finiteSD,globalSpeakers.(metric),group);
    summary.(metric+"N") = splitapply(@(x)sum(isfinite(x)),globalSpeakers.(metric),group);
end
writetable(globalSpeakers,fullfile(tablesFolder,"global_speaker_results.csv"));
writetable(summary,fullfile(tablesFolder,"global_summary.csv"));

keys = ["SpeakerId","UtteranceId","Segment","Class","Phone", ...
    "StartSeconds","EndSeconds","FrameCount","BoundaryFrameFraction"];
tokens = unique(phones(:,keys),"rows");
tokens.DurationMs = 1000*(tokens.EndSeconds-tokens.StartSeconds);
[group,coverage] = findgroups(tokens(:,"Class"));
coverage.TokenCount = splitapply(@numel,tokens.Segment,group);
coverage.TokensWithoutFrames = splitapply(@(x)sum(x==0),tokens.FrameCount,group);
coverage.TokensWithoutInteriorFrames = splitapply(@(x)sum(x==1 | isnan(x)),tokens.BoundaryFrameFraction,group);
coverage.MinimumDurationMs = splitapply(@min,tokens.DurationMs,group);
coverage.MedianDurationMs = splitapply(@median,tokens.DurationMs,group);
writetable(coverage,fullfile(tablesFolder,"label_coverage.csv"));

classes = ["vowels","nasals_approximants","fricatives","stops_affricates"];
names = ["Vowels","Nasals and approximants","Fricatives","Stops and affricates"];
noises = unique(speakers.Noise,"stable");
snrs = unique(speakers.SNRdB);
contrasts = {};
for noise = noises'
    for snr = snrs'
        reference = sortrows(speakers(speakers.Noise==noise & ...
            speakers.SNRdB==snr & speakers.Class=="vowels",:),"SpeakerId");
        for cls = classes(2:end)
            rows = sortrows(speakers(speakers.Noise==noise & ...
                speakers.SNRdB==snr & speakers.Class==cls,:),"SpeakerId");
            assert(isequal(rows.SpeakerId,reference.SpeakerId),"Unpaired class comparison.");
            result = pairedStats(rows.SpeechRetentiondB-reference.SpeechRetentiondB);
            result.Noise = noise; result.SNRdB = snr; result.Class = cls;
            contrasts{end+1} = result; %#ok<AGROW>
        end
    end
end
writetable(struct2table(vertcat(contrasts{:})),fullfile(tablesFolder,"class_contrasts.csv"));

% Equal weight for each condition within each speaker before pooling speakers.
keep = ismember(speakers.Class,classes);
[group,pooled] = findgroups(speakers(keep,["SpeakerId","Class"]));
metrics = ["SpeechRetentiondB","FrameSpeechRetentiondB","ResidualNoiseRatiodB", ...
    "MeanGain","WeightedGain","GainBelow1k","Gain1to4k","Gain4to8k", ...
    "HighFrequencyRetentiondB","SpeechLSDdB","MixtureLSDdB"];
for metric = metrics
    values = speakers.(metric);
    pooled.(metric) = splitapply(@finiteMean,values(keep),group);
end
[group,summary] = findgroups(pooled(:,"Class"));
for metric = metrics
    summary.(metric+"Mean") = splitapply(@finiteMean,pooled.(metric),group);
    summary.(metric+"SD") = splitapply(@finiteSD,pooled.(metric),group);
    summary.(metric+"N") = splitapply(@(x)sum(isfinite(x)),pooled.(metric),group);
end
writetable(summary,fullfile(tablesFolder,"pooled_class_summary.csv"));
if ~makeFigures, return; end
[~,order] = ismember(classes,summary.Class);
summary = summary(order,:);

fig = figure(Visible="off",Color="w",Position=[50 50 900 620]);
fields = ["SpeechRetentiondB","ResidualNoiseRatiodB"];
values = [summary.SpeechRetentiondBMean,summary.ResidualNoiseRatiodBMean];
bars = bar(values); hold on;
for k = 1:2
    errorbar(bars(k).XEndPoints,values(:,k),summary.(fields(k)+"SD"), ...
        "k",LineStyle="none",CapSize=10,HandleVisibility="off");
end
xticks(1:4); xticklabels(names); xtickangle(10); grid on;
ylabel("Component energy retention (dB)");
title("Speech attenuation and noise suppression");
subtitle("Speaker means pooled across conditions; bars show SD");
legend([bars(1),bars(2)],["Desired speech","Noise"],Location="southoutside");
savePlot(fig,"speech_noise_tradeoff");

fig = figure(Visible="off",Color="w",Position=[50 50 900 620]);
hold on;
for k = 1:4
    fields = ["GainBelow1k","Gain1to4k","Gain4to8k"];
    values = arrayfun(@(field)summary.(field+"Mean")(k),fields);
    plot(1:3,values,"o-",LineWidth=1.5,DisplayName=names(k));
end
xticks(1:3); xticklabels(["Below 1 kHz","1-4 kHz","4-8 kHz"]);
xlim([0.7 3.3]); ylim([0 1]); grid on; ylabel("Unweighted mean Wiener gain");
title("Frequency-dependent gain by phonetic class");
subtitle("Equal speaker weights; all noise types and input SNR levels pooled");
legend(Location="southoutside",NumColumns=2);
savePlot(fig,"frequency_gain");

    function savePlot(fig,name)
        set(findall(fig,"-property","FontName"),"FontName","Times New Roman");
        set(findall(fig,"Type","axes"),"FontSize",15);
        exportgraphics(fig,fullfile(figuresFolder,name+".png"),Resolution=200);
        close(fig);
    end
end

function value = finiteMean(x)
x=x(isfinite(x));
if isempty(x), value=NaN; else, value=mean(x); end
end

function value = finiteSD(x)
x=x(isfinite(x));
if numel(x)<2, value=NaN; else, value=std(x); end
end
