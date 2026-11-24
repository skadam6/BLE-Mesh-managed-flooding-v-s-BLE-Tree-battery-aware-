%% Run all simulation campaigns used by the paper
clear; clc; close all;
thisDir = fileparts(mfilename('fullpath'));
oldDir = pwd;
cleanup = onCleanup(@() cd(oldDir));
cd(thisDir);

fprintf('1/3 Baseline simulation\n');
run(fullfile(thisDir,'01_baseline_simulation.m'));
fprintf('2/3 Validation simulation\n');
run(fullfile(thisDir,'02_validation_simulation.m'));
fprintf('3/3 Sensitivity simulation\n');
run(fullfile(thisDir,'03_sensitivity_simulation.m'));
fprintf('All simulation campaigns completed.\n');
