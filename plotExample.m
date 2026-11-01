function plotExample(result,labels,figuresFolder,audioFolder,c)
% Export separate, readable figures for one fixed example.
prefix = result.PrefixSamples;
samples = prefix+(1:labels.End(end));
centres = (result.Centres-prefix)/c.SampleRate;
frequency = result.Frequency/1000;
bins = 1:numel(frequency);
duration = labels.End(end)/c.SampleRate;
valid = centres>=0 & centres<duration;
cleanSpectrum = result.S(bins,:);
noisySpectrum = result.Y(bins,:);
enhancedSpectrum = result.Gain(bins,:).*noisySpectrum;
reference = max(abs(cleanSpectrum(:,valid)),[],"all");

for part = 1:2
    fig = newFigure();
    plot((0:numel(samples)-1)/c.SampleRate,result.Clean(samples));
    xlim([(part-1)*duration/2 part*duration/2]); grid on;
    xlabel("Time (s)"); ylabel("Amplitude");
    title("Clean speech and phone boundaries");
    peak = max(abs(result.Clean(samples)));
    ylim([-1.1*peak 1.6*peak]);
    for k = 1:height(labels)
        start = labels.Start(k)/c.SampleRate;
        midpoint = (labels.Start(k)+labels.End(k))/(2*c.SampleRate);
        if midpoint >= (part-1)*duration/2 && midpoint < part*duration/2
            xline(start,":",Color=[0.5 0.5 0.5]);
            labelHeight = peak*(1.45-0.18*mod(k,2));
            alignment = "center";
            if midpoint > part*duration/2-0.08, alignment="right"; end
            if midpoint < (part-1)*duration/2+0.08, alignment="left"; end
            text(midpoint,labelHeight,labels.Phone(k), ...
                HorizontalAlignment=alignment,FontSize=10,Clipping="on");
        end
    end
    savePlot(fig,"example_phone_boundaries_"+part);
end

spectra = {cleanSpectrum,noisySpectrum,enhancedSpectrum};
titles = ["Clean speech","Noisy speech","Enhanced speech"];
names = ["clean","noisy","enhanced"];
for k = 1:3
    fig = newFigure();
    level = 20*log10(max(abs(spectra{k}(:,valid))/reference,1e-6));
    imagesc(centres(valid),frequency,level);
    axis xy; clim([-70 0]); colormap(parula);
    cb = colorbar; cb.Label.String = "Magnitude / clean peak (dB)";
    xlabel("Time (s)"); ylabel("Frequency (kHz)");
    title(titles(k));
    subtitle("Utterance 5338-24640-0003; cafeteria noise; 0 dB input SNR");
    savePlot(fig,"example_spectrogram_"+names(k));
end
fig = newFigure();
layout=tiledlayout(fig,6,1,TileSpacing="compact",Padding="compact");
strip=nexttile(layout,1);
hold on;
classNames=["vowels","nasals_approximants","fricatives","stops_affricates","silence"];
classColours=[lines(4);0.75 0.75 0.75];
handles=gobjects(1,5);
for k=1:height(labels)
    classIndex=find(classNames==labels.Class(k));
    a=labels.Start(k)/c.SampleRate; b=labels.End(k)/c.SampleRate;
    handles(classIndex)=patch([a b b a],[0 0 1 1],classColours(classIndex,:), ...
        EdgeColor="w",LineWidth=0.3);
end
ylim([0 1]); xlim([0 duration]); axis off;
title(strip,"Phonetic class",FontWeight="normal");
key=legend(handles,["Vowels","Nasals and approximants","Fricatives", ...
    "Stops and affricates","Silence"],NumColumns=3);
key.Layout.Tile="south";
nexttile(layout,[5 1]);
imagesc(centres(valid),frequency,result.Gain(bins,valid));
axis xy; clim([0 1]); colormap(parula);
ylim([0 8]); yticks(0:2:8); xlim([0 duration]);
cb=colorbar; cb.Label.String="Wiener gain"; cb.Layout.Tile="east";
xlabel("Time (s)"); ylabel("Frequency (kHz)");
heading=title(layout,"Wiener time-frequency gain");
heading.FontName="Times New Roman"; heading.FontSize=15;
subheading=subtitle(layout,"Utterance 5338-24640-0003; cafeteria noise; 0 dB input SNR");
subheading.FontName="Times New Roman"; subheading.FontSize=13;
savePlot(fig,"example_gain");

classes = ["vowels","nasals_approximants","fricatives","stops_affricates"];
for cls = classes
    candidates = find(labels.Class==cls);
    counts = arrayfun(@(k)sum(result.Centres-prefix>=labels.Start(k) & ...
        result.Centres-prefix<labels.End(k)),candidates);
    [count,choice] = max(counts);
    if isempty(count) || count==0, continue; end
    token = candidates(choice);
    frames = result.Centres-prefix>=labels.Start(token) & result.Centres-prefix<labels.End(token);
    clean = sqrt(mean(abs(cleanSpectrum(:,frames)).^2,2));
    noisy = sqrt(mean(abs(noisySpectrum(:,frames)).^2,2));
    enhanced = sqrt(mean(abs(enhancedSpectrum(:,frames)).^2,2));
    fig = newFigure();
    curves=plot(frequency,20*log10(max([clean noisy enhanced]/max(clean),1e-6)),LineWidth=1.2);
    curves(1).Color=[0 0.447 0.741]; curves(1).LineStyle="-";
    curves(2).Color=[0.85 0.325 0.098]; curves(2).LineStyle="--";
    curves(3).Color=[0.494 0.184 0.556]; curves(3).LineStyle="-.";
    ylim([-80 25]); ylabel("Magnitude / clean peak (dB)");
    xlabel("Frequency (kHz)"); xlim([0 8]); grid on;
    classTitle=replace(cls,classes,["Vowel","Nasal or approximant","Fricative","Stop or affricate"]);
    title(classTitle+" spectrum ("+labels.Phone(token)+")");
    subtitle(sprintf("%.3f-%.3f s; cafeteria noise; 0 dB input SNR", ...
        labels.Start(token)/c.SampleRate,labels.End(token)/c.SampleRate));
    legend(curves,["Clean","Noisy","Enhanced"],Location="southoutside",NumColumns=3);
    savePlot(fig,"example_spectrum_"+cls);
    fig = newFigure();
    plot(frequency,mean(result.Gain(bins,frames),2),"k-",LineWidth=1.2);
    ylim([0 1]); xlim([0 8]); grid on;
    xlabel("Frequency (kHz)"); ylabel("Mean amplitude gain");
    title(classTitle+" Wiener gain ("+labels.Phone(token)+")");
    subtitle(sprintf("%.3f-%.3f s; cafeteria noise; 0 dB input SNR", ...
        labels.Start(token)/c.SampleRate,labels.End(token)/c.SampleRate));
    savePlot(fig,"example_phone_gain_"+cls);
end
signals=[result.Clean(samples),result.Noisy(samples),result.Enhanced(samples)];
scale=min(1,0.99/max(abs(signals),[],"all"));
for k=1:3
    audiowrite(fullfile(audioFolder,"example_"+names(k)+".wav"),signals(:,k)*scale,c.SampleRate);
end

    function fig=newFigure()
        fig=figure(Visible="off",Color="w",Position=[50 50 900 600]);
    end
    function savePlot(fig,name)
        set(findall(fig,"-property","FontName"),"FontName","Times New Roman");
        set(findall(fig,"Type","axes"),"FontSize",15);
        exportgraphics(fig,fullfile(figuresFolder,name+".png"),Resolution=200);
        close(fig);
    end
end
