function plotExample(result,labels,figuresFolder,audioFolder,c)
% Show one aligned example and save clean, noisy and enhanced audio.

prefix = result.PrefixSamples;
samples = prefix + (1:labels.End(end));
centres = (result.Centres-prefix)/c.SampleRate;
frequency = result.Frequency/1000;
bins = 1:numel(frequency);
valid = centres >= 0 & centres < labels.End(end)/c.SampleRate;

cleanSpectrum = result.S(bins,:);
noisySpectrum = result.Y(bins,:);
enhancedSpectrum = result.Gain(bins,:).*noisySpectrum;
reference = max(abs(cleanSpectrum(:,valid)),[],"all");

fig = figure(Visible="off",Color="w",Position=[50 50 1300 680]);
tiledlayout(2,1,Padding="compact",TileSpacing="compact");
duration = labels.End(end)/c.SampleRate;
drawWaveform(0,duration/2);
drawWaveform(duration/2,duration);
sgtitle("Clean speech and phone boundaries");
applyReportFont(fig);
exportgraphics(fig,fullfile(figuresFolder,"figure5_phone_boundaries.png"),Resolution=200);
close(fig);

fig = figure(Visible="off",Color="w",Position=[50 50 1300 820]);
tiledlayout(2,2,Padding="compact",TileSpacing="compact");
drawSpectrogram(cleanSpectrum,"Clean speech");
drawSpectrogram(noisySpectrum,"Noisy speech at 0 dB SNR");
drawSpectrogram(enhancedSpectrum,"Enhanced speech");

nexttile;
imagesc(centres(valid),frequency,result.Gain(bins,valid));
axis xy; clim([0 1]); colorbar;
xlabel("Time (s)"); ylabel("Frequency (kHz)"); title("Wiener gain");
markPhones(false);
applyReportFont(fig);
exportgraphics(fig,fullfile(figuresFolder,"figure6_time_frequency.png"),Resolution=200);
close(fig);

fig = figure(Visible="off",Color="w",Position=[50 50 1300 820]);
tiledlayout(2,2,Padding="compact",TileSpacing="compact");
drawPhoneSpectrum("vowels","Representative vowel");
drawPhoneSpectrum("nasals_approximants","Representative nasal / approximant");
drawPhoneSpectrum("fricatives","Representative fricative");
drawPhoneSpectrum("stops_affricates","Representative stop / affricate");
applyReportFont(fig);
exportgraphics(fig,fullfile(figuresFolder,"figure7_class_spectra.png"),Resolution=200);
close(fig);

signals = [result.Clean(samples),result.Noisy(samples),result.Enhanced(samples)];
scale = min(1,0.99/max(abs(signals),[],"all"));
audiowrite(fullfile(audioFolder,"example_clean.wav"),signals(:,1)*scale,c.SampleRate);
audiowrite(fullfile(audioFolder,"example_noisy.wav"),signals(:,2)*scale,c.SampleRate);
audiowrite(fullfile(audioFolder,"example_enhanced.wav"),signals(:,3)*scale,c.SampleRate);

    function drawSpectrogram(spectrumData,plotTitle)
        nexttile;
        magnitude = 20*log10(max(abs(spectrumData(:,valid))/max(reference,realmin),1e-6));
        imagesc(centres(valid),frequency,magnitude);
        axis xy; clim([-70 0]); colorbar;
        xlabel("Time (s)"); ylabel("Frequency (kHz)"); title(plotTitle);
        markPhones(false);
    end

    function drawWaveform(startTime,endTime)
        nexttile;
        plot((0:labels.End(end)-1)/c.SampleRate,result.Clean(samples));
        xlim([startTime endTime]); grid on;
        xlabel("Time (s)"); ylabel("Amplitude");
        markPhones(true);
    end

    function drawPhoneSpectrum(phoneClass,plotTitle)
        candidates = find(labels.Class == phoneClass);
        frameCount = arrayfun(@(index)nnz(result.Centres-prefix >= labels.Start(index) & ...
            result.Centres-prefix < labels.End(index)),candidates);
        [~,longest] = max(frameCount);
        token = candidates(longest);
        frames = result.Centres-prefix >= labels.Start(token) & ...
            result.Centres-prefix < labels.End(token);
        clean = sqrt(mean(abs(cleanSpectrum(:,frames)).^2,2));
        noisy = sqrt(mean(abs(noisySpectrum(:,frames)).^2,2));
        enhanced = sqrt(mean(abs(enhancedSpectrum(:,frames)).^2,2));
        level = max(clean);
        nexttile;
        plot(frequency,20*log10(max([clean,noisy,enhanced]/max(level,realmin),1e-6)));
        grid on; xlabel("Frequency (kHz)"); ylabel("Relative magnitude (dB)");
        title(plotTitle+" ("+labels.Phone(token)+")",Interpreter="none");
        legend("Clean","Noisy","Enhanced",Location="best");
    end

    function markPhones(showText)
        hold on;
        limits = ylim;
        timeLimits = xlim;
        for index = 1:height(labels)
            startTime = labels.Start(index)/c.SampleRate;
            midpoint = (labels.Start(index)+labels.End(index))/(2*c.SampleRate);
            if startTime >= timeLimits(1) && startTime <= timeLimits(2)
                xline(startTime,":",Color=[0.45 0.45 0.45]);
            end
            if showText && midpoint >= timeLimits(1) && midpoint <= timeLimits(2) && ...
                    (labels.End(index)-labels.Start(index))/c.SampleRate >= 0.04
                text(midpoint,limits(2)-0.07*diff(limits),labels.Phone(index), ...
                    Rotation=90,HorizontalAlignment="right",FontSize=8, ...
                    FontName="Times New Roman",Interpreter="none");
            end
        end
        hold off;
    end

    function applyReportFont(targetFigure)
        set(findall(targetFigure,"-property","FontName"), ...
            "FontName","Times New Roman");
    end
end
