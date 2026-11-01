function compareWindows
% Compare 16 ms and 32 ms windows using identical mixtures.
root=fileparts(mfilename("fullpath"));
baselineFolder=fullfile(root,"results");
comparisonFolder=fullfile(baselineFolder,"window_comparison");
main(512,baselineFolder,true);
main(256,comparisonFolder,false);
readResult=@(folder,name)readtable(fullfile(folder,"tables",name+".csv"),TextType="string");
b=readResult(baselineFolder,"global_results");
s=readResult(comparisonFolder,"global_results");
keys=["SpeakerId","UtteranceId","Noise","SNRdB","Repeat"];
b=sortrows(b,keys); s=sortrows(s,keys);
assert(isequal(b(:,keys),s(:,keys)),"Window comparison uses different conditions.");
assert(isequal(b.NoiseStartSample,s.NoiseStartSample) && ...
    isequal(b.NoiseScale,s.NoiseScale),"Mixtures must be identical across windows.");
assert(max(abs(b.InputErrorSNRdB-s.InputErrorSNRdB))<1e-10,"Input SNR mismatch.");
b.DeltaSTOI=b.OutputSTOI-b.InputSTOI;
s.DeltaSTOI=s.OutputSTOI-s.InputSTOI;
globalMetrics=["DeltaErrorSNRdB","DeltaSTOI","SpeechRetentiondB","ResidualNoiseRatiodB"];
rows={};
for metric=globalMetrics
    [group,paired]=findgroups(b(:,["SpeakerId","Noise","SNRdB"]));
    paired.Baseline=splitapply(@mean,b.(metric),group);
    paired.Short=splitapply(@mean,s.(metric),group);
    rows=[rows; compareConditions(paired,"whole_utterance",metric)]; %#ok<AGROW>
end
b=sortrows(readResult(baselineFolder,"speaker_results"),["SpeakerId","Noise","SNRdB","Class"]);
s=sortrows(readResult(comparisonFolder,"speaker_results"),["SpeakerId","Noise","SNRdB","Class"]);
assert(isequal(b(:,["SpeakerId","Noise","SNRdB","Class"]), ...
    s(:,["SpeakerId","Noise","SNRdB","Class"])),"Unpaired speaker results.");
for cls=["vowels","nasals_approximants","fricatives","stops_affricates"]
    chosen=b.Class==cls;
    for metric=["SpeechRetentiondB","BoundaryFrameFraction"]
        paired=b(chosen,["SpeakerId","Noise","SNRdB"]);
        paired.Baseline=b.(metric)(chosen);
        paired.Short=s.(metric)(chosen);
        rows=[rows; compareConditions(paired,cls,metric)]; %#ok<AGROW>
    end
end
comparison=struct2table(vertcat(rows{:}));
writetable(comparison,fullfile(comparisonFolder,"window_comparison.csv"));

selected=comparison.Metric=="SpeechRetentiondB" & comparison.Noise=="all" & ...
    comparison.Class~="whole_utterance";
plotRows=comparison(selected,:);
fig=figure(Visible="off",Color="w",Position=[50 50 900 620]);
errorbar(1:height(plotRows),plotRows.MeanDifference, ...
    plotRows.MeanDifference-plotRows.Lower95,plotRows.Upper95-plotRows.MeanDifference, ...
    "ko",LineWidth=1.5,CapSize=12);
yline(0,"--"); grid on;
xticks(1:height(plotRows));
xticklabels(replace(plotRows.Class,["vowels","nasals_approximants","fricatives","stops_affricates"], ...
    ["Vowels","Nasals and approximants","Fricatives","Stops and affricates"])); xtickangle(10);
xlim([0.5 height(plotRows)+0.5]);
ylabel("Speech retention difference: 16 ms minus 32 ms (dB)");
title("Window-length sensitivity of speech retention");
subtitle("Paired speaker means; 95% bootstrap intervals; all conditions pooled");
set(findall(fig,"-property","FontName"),"FontName","Times New Roman");
set(findall(fig,"Type","axes"),"FontSize",15);
exportgraphics(fig,fullfile(comparisonFolder,"window_retention_change.png"),Resolution=200);
close(fig);
disp(comparison(comparison.Noise=="all",:));
end

function rows=compareConditions(paired,cls,metric)
rows={};
conditions=unique(paired(:,["Noise","SNRdB"]),"rows");
for k=1:height(conditions)+1
    if k<=height(conditions)
        selected=paired.Noise==conditions.Noise(k) & paired.SNRdB==conditions.SNRdB(k);
        values=paired(selected,:);
        noise=conditions.Noise(k); snr=conditions.SNRdB(k);
    else
        [group,values]=findgroups(paired(:,"SpeakerId"));
        values.Baseline=splitapply(@mean,paired.Baseline,group);
        values.Short=splitapply(@mean,paired.Short,group);
        noise="all"; snr=NaN;
    end
    result=pairedStats(values.Short-values.Baseline);
    result.Class=cls; result.Metric=metric; result.Noise=noise; result.SNRdB=snr;
    result.BaselineMean=mean(values.Baseline,"omitnan");
    result.ShortWindowMean=mean(values.Short,"omitnan");
    rows{end+1,1}=result; %#ok<AGROW>
end
end
