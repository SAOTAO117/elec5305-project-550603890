function labels = loadPhoneLabels(filename,fs,nSamples)
% Read phone boundaries supplied with the speech corpus.

data = readtable(filename,TextType="string",VariableNamingRule="preserve");
required = ["start_s","end_s","phone","class"];
assert(all(ismember(required,string(data.Properties.VariableNames))), ...
    "The label file is missing a required column.");

startSample = round(data.start_s*fs);
endSample = round(data.end_s*fs);
labels = table(startSample,endSample,string(data.phone),string(data.class), ...
    VariableNames=["Start","End","Phone","Class"]);

assert(labels.Start(1) == 0 && labels.End(end) == nSamples, ...
    "Phone labels must cover the complete audio file.");
assert(all(labels.End > labels.Start),"Phone intervals must have positive duration.");
assert(all(labels.Start(2:end) == labels.End(1:end-1)), ...
    "Phone intervals must be continuous and non-overlapping.");
end
