function stats = pairedStats(differences)
% Bootstrap complete speaker-level paired differences, not individual phones.
differences = differences(isfinite(differences));
n = numel(differences);
stats = struct("NumberOfSpeakers",n,"MeanDifference",NaN, ...
    "SDDifference",NaN,"Lower95",NaN,"Upper95",NaN);
if n == 0, return; end
stats.MeanDifference = mean(differences);
if n < 2, return; end
stats.SDDifference = std(differences);
stream = RandStream("mt19937ar",Seed=5305);
indices = randi(stream,n,n,10000);
sampleMeans = sort(mean(reshape(differences(indices),n,10000),1));
stats.Lower95 = interp1((1:10000)/10000,sampleMeans,0.025);
stats.Upper95 = interp1((1:10000)/10000,sampleMeans,0.975);
end
