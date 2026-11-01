function main(windowLength,resultsFolder,makeFigures)
% Main experiment for phonetic preservation in Wiener speech enhancement.

projectFolder = fileparts(mfilename("fullpath"));
dataFolder = fullfile(projectFolder,"data");
if nargin < 1, windowLength = 512; end
if nargin < 2, resultsFolder = fullfile(projectFolder,"results"); end
if nargin < 3, makeFigures = true; end
tablesFolder = fullfile(resultsFolder,"tables");
figuresFolder = fullfile(resultsFolder,"figures");
audioFolder = fullfile(resultsFolder,"audio");
c = experimentSettings(windowLength);

speechInfo = readtable(fullfile(dataFolder,"speechManifest.csv"),TextType="string");
noiseInfo = readtable(fullfile(dataFolder,"noiseManifest.csv"),TextType="string");
assert(numel(unique(speechInfo.speaker_id)) == height(speechInfo), ...
    "This experiment expects one utterance per speaker.");

speechAudio = cell(height(speechInfo),1);
phoneLabels = cell(height(speechInfo),1);
for i = 1:height(speechInfo)
    [x,fs] = audioread(fullfile(dataFolder,speechInfo.audio_path(i)));
    assert(fs == c.SampleRate,"All speech files must be sampled at 16 kHz.");
    speechAudio{i} = x(:,1);
    phoneLabels{i} = loadPhoneLabels( ...
        fullfile(dataFolder,speechInfo.labels_path(i)),fs,numel(x(:,1)));
end

noiseAudio = cell(height(noiseInfo),1);
for i = 1:height(noiseInfo)
    [x,fs] = audioread(fullfile(dataFolder,noiseInfo.audio_path(i)));
    assert(fs == c.SampleRate,"All noise files must be sampled at 16 kHz.");
    noiseAudio{i} = x(:,noiseInfo.channel(i));
end

phoneRows = {};
globalRows = {};
example = [];
prefixLength = round(c.CalibrationSeconds*c.SampleRate);

for speechIndex = 1:height(speechInfo)
    cleanSpeech = speechAudio{speechIndex};
    labels = phoneLabels{speechIndex};
    activeSpeech = false(size(cleanSpeech));
    for k = 1:height(labels)
        if labels.Class(k) ~= "silence"
            activeSpeech(labels.Start(k)+1:labels.End(k)) = true;
        end
    end

    for noiseIndex = 1:height(noiseInfo)
        requiredLength = prefixLength + numel(cleanSpeech);
        assert(numel(noiseAudio{noiseIndex}) >= requiredLength,"Noise recording is too short.");
        for repeat = 1:c.NoiseRepeats
            seed = c.RandomSeed + 100000*speechIndex + 1000*noiseIndex + repeat;
            stream = RandStream("mt19937ar",Seed=seed);
            cropStart = randi(stream,numel(noiseAudio{noiseIndex})-requiredLength+1);
            noiseSegment = noiseAudio{noiseIndex}(cropStart:cropStart+requiredLength-1);
            evaluationNoise = noiseSegment(prefixLength+1:end);

            for snrDb = c.InputSNRdB
                scale = sqrt(mean(cleanSpeech(activeSpeech).^2) / ...
                    (mean(evaluationNoise(activeSpeech).^2)*10^(snrDb/10)));
                clean = [zeros(prefixLength,1); cleanSpeech];
                addedNoise = scale*noiseSegment;
                noisy = clean + addedNoise;

                filtered = wienerFilter(noisy,clean,addedNoise,prefixLength,c);
                measuredSNR = 10*log10(sum(cleanSpeech(activeSpeech).^2) / ...
                    sum((scale*evaluationNoise(activeSpeech)).^2));
                assert(abs(measuredSNR-snrDb)<1e-10,"Input SNR calibration failed.");
                [phoneTable,globalTable] = phoneMetrics( ...
                    filtered,labels,measuredSNR,c);

                phoneTable.SpeakerId = repmat(speechInfo.speaker_id(speechIndex),height(phoneTable),1);
                phoneTable.UtteranceId = repmat(speechInfo.utterance_id(speechIndex),height(phoneTable),1);
                phoneTable.Noise = repmat(noiseInfo.noise_id(noiseIndex),height(phoneTable),1);
                phoneTable.SNRdB = repmat(snrDb,height(phoneTable),1);
                phoneTable.Repeat = repmat(repeat,height(phoneTable),1);
                phoneTable = movevars(phoneTable, ...
                    ["SpeakerId","UtteranceId","Noise","SNRdB","Repeat"],Before=1);

                globalTable.SpeakerId = speechInfo.speaker_id(speechIndex);
                globalTable.UtteranceId = speechInfo.utterance_id(speechIndex);
                globalTable.Noise = noiseInfo.noise_id(noiseIndex);
                globalTable.SNRdB = snrDb;
                globalTable.Repeat = repeat;
                globalTable.NoiseStartSample = cropStart;
                globalTable.NoiseScale = scale;
                globalTable = movevars(globalTable, ...
                    ["SpeakerId","UtteranceId","Noise","SNRdB","Repeat"],Before=1);

                if isempty(example) && speechIndex == 1 && ...
                        noiseInfo.noise_id(noiseIndex) == "PCAFETER" && ...
                        snrDb == 0 && repeat == 1
                    example = struct("Filtered",filtered,"Labels",labels);
                end

                phoneRows{end+1} = phoneTable; %#ok<AGROW>
                globalRows{end+1} = globalTable; %#ok<AGROW>
            end
        end
    end
end

phoneResults = vertcat(phoneRows{:});
globalResults = vertcat(globalRows{:});
[classSummary,speakerResults] = summarisePhones(phoneResults);

outputFolders = [tablesFolder,figuresFolder,audioFolder];
for folder = outputFolders
    if ~isfolder(folder)
        mkdir(folder);
    end
end
writetable(phoneResults,fullfile(tablesFolder,"phone_results.csv"));
writetable(globalResults,fullfile(tablesFolder,"global_results.csv"));
writetable(classSummary,fullfile(tablesFolder,"class_summary.csv"));
writetable(speakerResults,fullfile(tablesFolder,"speaker_results.csv"));
configuration = rmfield(c,"Window");
configuration.InputSNRdB = string(mat2str(c.InputSNRdB));
configuration.MATLABVersion = string(version);
configuration.STOIAvailable = exist("stoi","file")==2;
writetable(struct2table(configuration),fullfile(tablesFolder,"configuration.csv"));
analyseResults(phoneResults,globalResults,speakerResults,tablesFolder,figuresFolder,makeFigures);
if makeFigures
    plotResults(globalResults,classSummary,speakerResults,figuresFolder);
    plotExample(example.Filtered,example.Labels,figuresFolder,audioFolder,c);
end

fprintf("Experiment complete. Results saved in:\n%s\n",resultsFolder);
end

function [summary,speaker] = summarisePhones(phoneResults)
metrics = ["MeanGain","GainBelow1k","Gain1to4k","Gain4to8k", ...
    "SpeechRetentiondB","HighFrequencyRetentiondB", ...
    "ResidualNoiseRatiodB","MixtureLSDdB","SpeechLSDdB", ...
    "DeltaErrorSNRdB","FrameSpeechRetentiondB","WeightedGain", ...
    "BoundaryFrameFraction"];

[group,tokens] = findgroups(phoneResults(:, ...
    ["SpeakerId","UtteranceId","Segment","Noise","SNRdB","Class"]));
for metric = metrics
    tokens.(metric) = splitapply(@meanFinite,phoneResults.(metric),group);
end

[group,speaker] = findgroups(tokens(:,["SpeakerId","Noise","SNRdB","Class"]));
for metric = metrics
    speaker.(metric) = splitapply(@meanFinite,tokens.(metric),group);
end

[group,summary] = findgroups(speaker(:,["Noise","SNRdB","Class"]));
summary.NumberOfSpeakers = splitapply(@numel,speaker.SpeakerId,group);
for metric = metrics
    summary.(metric+"Mean") = splitapply(@meanFinite,speaker.(metric),group);
    summary.(metric+"SD") = splitapply(@stdFinite,speaker.(metric),group);
    summary.(metric+"N") = splitapply(@(x)sum(isfinite(x)),speaker.(metric),group);
end
end

function plotResults(globalResults,classSummary,speakerResults,figuresFolder)
speechClasses = ["vowels","nasals_approximants","fricatives","stops_affricates"];
speechClassNames = ["Vowels","Nasals and approximants","Fricatives","Stops and affricates"];
gainClasses = [speechClasses,"silence"];
gainClassNames = [speechClassNames,"Silence"];
noises = unique(classSummary.Noise,"stable");
noiseTitles = replace(noises,["DKITCHEN","PCAFETER","STRAFFIC"], ...
    ["Kitchen noise (DKITCHEN)","Cafeteria noise (PCAFETER)","Traffic noise (STRAFFIC)"]);
colours = lines(4);
for i = 1:numel(noises)
    fig = figure(Visible="off",Color="w",Position=[50 50 900 620]);
    selected = speakerResults.Noise == noises(i) & speakerResults.SNRdB == 0;
    groups = categorical(speakerResults.Class(selected),gainClasses,gainClassNames);
    boxchart(groups,speakerResults.MeanGain(selected));
    ylim([0 1]); grid on; xtickangle(15);
    title(noiseTitles(i),Interpreter="none");
    subtitle("0 dB active-speech input SNR; 10 speaker means per class");
    ylabel("Unweighted mean Wiener gain");
    savePlot(fig,"gain_"+noises(i));
end
makeClassPlot("SpeechRetentiondB","Time-domain speech retention (dB)","speech_retention");
makeClassPlot("MixtureLSDdB","Mixture log-spectral distortion (dB)","spectral_distortion");
makeClassPlot("DeltaErrorSNRdB","Segmental error-SNR improvement (dB)","segmental_error_snr");
makeClassPlot("HighFrequencyRetentiondB","4-8 kHz speech retention (dB)","high_frequency_retention");
[group,globalSpeakers] = findgroups(globalResults(:,["SpeakerId","Noise","SNRdB"]));
globalSpeakers.Improvement = splitapply(@meanFinite,globalResults.DeltaErrorSNRdB,group);
group = findgroups(globalSpeakers(:,["Noise","SNRdB"]));
globalMeans = splitapply(@meanFinite,globalSpeakers.Improvement,group);
globalSDs = splitapply(@stdFinite,globalSpeakers.Improvement,group);
globalLimits = [min(0,floor(min(globalMeans-globalSDs))),ceil(max(globalMeans+globalSDs))];
for i = 1:numel(noises)
    fig = figure(Visible="off",Color="w",Position=[50 50 900 620]);
    rows = globalResults(globalResults.Noise == noises(i),:);
    [group,speakers] = findgroups(rows(:,["SpeakerId","SNRdB"]));
    speakers.Improvement = splitapply(@meanFinite,rows.DeltaErrorSNRdB,group);
    [group,snrValues] = findgroups(speakers.SNRdB);
    means = splitapply(@meanFinite,speakers.Improvement,group);
    deviations = splitapply(@stdFinite,speakers.Improvement,group);
    errorbar(snrValues,means,deviations,"ko-",LineWidth=1.5,CapSize=12);
    xlabel("Active-speech input SNR (dB)"); xticks([-5 0 5 10]);
    ylabel("Global error-SNR improvement (dB)"); grid on;
    ylim(globalLimits); xlim([-6 11]);
    title(noiseTitles(i),Interpreter="none");
    subtitle("Mean and SD across 10 speakers");
    savePlot(fig,"global_error_snr_"+noises(i));
end
    function makeClassPlot(fieldName,yLabel,fileName)
        lower = classSummary.(fieldName+"Mean")-classSummary.(fieldName+"SD");
        upper = classSummary.(fieldName+"Mean")+classSummary.(fieldName+"SD");
        keep = ismember(classSummary.Class,speechClasses);
        limits = [floor(min(lower(keep))),ceil(max(upper(keep)))];
        if limits(1)==limits(2), limits=limits+[-1 1]; end
        for noiseIndex = 1:numel(noises)
            fig = figure(Visible="off",Color="w",Position=[50 50 900 620]);
            hold on;
            for classIndex = 1:4
                selected = classSummary.Noise == noises(noiseIndex) & ...
                    classSummary.Class == speechClasses(classIndex);
                rows = sortrows(classSummary(selected,:),"SNRdB");
                offset = (classIndex-2.5)*0.12;
                errorbar(rows.SNRdB+offset,rows.(fieldName+"Mean"),rows.(fieldName+"SD"),"o-", ...
                    LineWidth=1.3,CapSize=8,Color=colours(classIndex,:), ...
                    DisplayName=speechClassNames(classIndex));
            end
            hold off; grid on; xlabel("Active-speech input SNR (dB)"); ylabel(yLabel);
            xticks([-5 0 5 10]); xlim([-6 11]); ylim(limits);
            title(noiseTitles(noiseIndex),Interpreter="none");
            subtitle("Mean and SD across 10 speakers");
            legend(Location="southoutside",NumColumns=2);
            savePlot(fig,fileName+"_"+noises(noiseIndex));
        end
    end
    function savePlot(fig,name)
        applyReportFont(fig);
        exportgraphics(fig,fullfile(figuresFolder,name+".png"),Resolution=200);
        close(fig);
    end
end

function applyReportFont(fig)
set(findall(fig,"-property","FontName"),"FontName","Times New Roman");
set(findall(fig,"Type","axes"),"FontSize",15);
end

function value = meanFinite(values)
values = values(isfinite(values));
if isempty(values), value = NaN; else, value = mean(values); end
end

function value = stdFinite(values)
values = values(isfinite(values));
if numel(values) < 2, value = NaN; else, value = std(values); end
end
