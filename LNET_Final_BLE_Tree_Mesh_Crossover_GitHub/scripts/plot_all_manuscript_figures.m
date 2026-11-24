%% Regenerate all figure panels used in the manuscript from frozen CSV data
clear; clc; close all;
scriptDir = fileparts(mfilename('fullpath'));
files = {'plot_Fig02_baseline.m','plot_Fig03_crossover_geometry.m','plot_Fig04_relay_fraction.m', ...
         'plot_Fig05_communication_model.m','plot_Fig06_failure_recovery.m','plot_Fig07_duty_load.m'};
for k=1:numel(files)
    fprintf('Running %s\n',files{k});
    run(fullfile(scriptDir,files{k}));
end
fprintf('All manuscript figure panels regenerated under figures/generated/.\n');
