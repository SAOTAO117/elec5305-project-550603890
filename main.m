function main
% Main experiment for phonetic preservation in Wiener speech enhancement.

projectFolder = fileparts(mfilename("fullpath"));
dataFolder = fullfile(projectFolder,"data");
resultsFolder = fullfile(projectFolder,"results");
tablesFolder = fullfile(resultsFolder,"tables");
figuresFolder = fullfile(resultsFolder,"figures");
audioFolder = fullfile(resultsFolder,"audio");
c = experimentSettings();

speechInfo = readtable(fullfile(dataFolder,"speechManifest.csv"),TextType="string");
noiseInfo = readtable(fullfile(dataFolder,"noiseManifest.csv"),TextType="string");

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
plotResults(globalResults,classSummary,speakerResults,figuresFolder);
plotExample(example.Filtered,example.Labels,figuresFolder,audioFolder,c);

fprintf("Experiment complete. Results saved in:\n%s\n",resultsFolder);
end

function c = experimentSettings
c.SampleRate = 16000;
c.WindowLength = 512;
c.HopLength = 256;
c.OverlapLength = 256;
c.FFTLength = 512;
c.Window = sqrt(hann(c.WindowLength,"periodic"));
c.NoiseSmoothing = 0.8;
c.GainFloor = 0.05;
c.CalibrationSeconds = 0.5;
c.InputSNRdB = [-5 0 5 10];
c.NoiseRepeats = 2;
c.RandomSeed = 5305;
end

function [summary,speaker] = summarisePhones(phoneResults)
metrics = ["MeanGain","GainBelow1k","Gain1to4k","Gain4to8k", ...
    "SpeechRetentiondB","HighFrequencyRetentiondB", ...
    "ResidualNoiseRatiodB","MixtureLSDdB","SpeechLSDdB", ...
    "DeltaErrorSNRdB"];

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
end
end

function plotResults(globalResults,classSummary,speakerResults,figuresFolder)
speechClasses = ["vowels","nasals_approximants","fricatives","stops_affricates"];
speechClassNames = ["Vowels","Nasals / approximants","Fricatives","Stops / affricates"];
gainClasses = [speechClasses,"silence"];
gainClassNames = [speechClassNames,"Silence"];
noises = unique(classSummary.Noise,"stable");
colours = lines(4);

fig = figure(Visible="off",Color="w",Position=[50 50 1200 480]);
tiledlayout(1,numel(noises),Padding="compact");
for i = 1:numel(noises)
    nexttile;
    selected = speakerResults.Noise == noises(i) & speakerResults.SNRdB == 0;
    groups = categorical(speakerResults.Class(selected),gainClasses,gainClassNames);
    boxchart(groups,speakerResults.MeanGain(selected));
    ylim([0 1]); grid on; xtickangle(25); title(noises(i),Interpreter="none");
    ylabel("Mean Wiener gain");
end
applyReportFont(fig);
exportgraphics(fig,fullfile(figuresFolder,"figure2_gain_by_class.png"),Resolution=200);
close(fig);

makeClassPlot("SpeechRetentiondBMean","Speech retention (dB)", ...
    "figure3_retention_vs_snr.png");
makeClassPlot("MixtureLSDdBMean","Log-spectral distortion (dB)", ...
    "figure4_spectral_distortion.png");

fig = figure(Visible="off",Color="w",Position=[50 50 1200 480]);
tiledlayout(1,numel(noises),Padding="compact");
for i = 1:numel(noises)
    nexttile;
    rows = globalResults(globalResults.Noise == noises(i),:);
    [group,snrValues] = findgroups(rows.SNRdB);
    snrImprovement = splitapply(@meanFinite,rows.DeltaErrorSNRdB,group);
    [snrValues,order] = sort(snrValues);
    yyaxis left;
    plot(snrValues,snrImprovement(order),"ks--",LineWidth=1.3, ...
        DisplayName="Global SNR improvement");
    ylabel("Global SNR improvement (dB)"); grid on;
    yyaxis right; hold on;
    for k = 1:4
        selected = classSummary.Noise == noises(i) & classSummary.Class == speechClasses(k);
        rows = sortrows(classSummary(selected,:),"SNRdB");
        plot(rows.SNRdB,rows.MixtureLSDdBMean,"o-",Color=colours(k,:), ...
            DisplayName=speechClassNames(k));
    end
    hold off; xlabel("Input SNR (dB)");
    ylabel("Phoneme-class distortion (dB)");
    title(noises(i),Interpreter="none");
    if i == 1, legend(Location="best"); end
end
applyReportFont(fig);
exportgraphics(fig,fullfile(figuresFolder,"figure1_global_vs_phonetic.png"),Resolution=200);
close(fig);

    function makeClassPlot(fieldName,yLabel,fileName)
        fig = figure(Visible="off",Color="w",Position=[50 50 1200 480]);
        tiledlayout(1,numel(noises),Padding="compact");
        for noiseIndex = 1:numel(noises)
            nexttile; hold on;
            for classIndex = 1:4
                selected = classSummary.Noise == noises(noiseIndex) & ...
                    classSummary.Class == speechClasses(classIndex);
                rows = sortrows(classSummary(selected,:),"SNRdB");
                plot(rows.SNRdB,rows.(fieldName),"o-", ...
                    Color=colours(classIndex,:),DisplayName=speechClassNames(classIndex));
            end
            hold off; grid on; xlabel("Input SNR (dB)"); ylabel(yLabel);
            title(noises(noiseIndex),Interpreter="none");
            if noiseIndex == 1, legend(Location="best"); end
        end
        applyReportFont(fig);
        exportgraphics(fig,fullfile(figuresFolder,fileName),Resolution=200);
        close(fig);
    end
end

function applyReportFont(fig)
set(findall(fig,"-property","FontName"),"FontName","Times New Roman");
end

function value = meanFinite(values)
values = values(isfinite(values));
if isempty(values), value = NaN; else, value = mean(values); end
end

function value = stdFinite(values)
values = values(isfinite(values));
if numel(values) < 2, value = NaN; else, value = std(values); end
end
