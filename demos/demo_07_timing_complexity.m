% demo_07_timing_complexity.m
% Measures and plots the Big-O time complexity of Software vs Hardware FFTs

clear; clc; close all;
addpath('../core_engines');

disp('Starting Demo 07: Execution Time Complexity');

cacheFile = '../cache/demo_07_cache.mat';
if isfile(cacheFile)
    disp('Found cached simulation data. Loading instantly...');
    load(cacheFile);
    for idx = 1:length(symbolsList)
        S = symbolsList(idx);
        fprintf('Symbols: %6d | SW Time: %8.2f us | HW Time: %8.2f us | Speedup: %.2fx\n', ...
            S, timeSoftware(idx)*1e6, timeHardware(idx)*1e6, timeSoftware(idx)/timeHardware(idx));
    end
else
    disp('Cache not found. Running Timing Benchmarks (This may take a moment)...');
    
    symbolsList = [1, 10, 100, 1000, 10000, 100000];
    N = 64;
    numCores = 8;
    numTrials = 10; % Average over trials to remove OS jitter

    timeSoftware = zeros(length(symbolsList), 1);
    timeHardware = zeros(length(symbolsList), 1);

    for idx = 1:length(symbolsList)
        S = symbolsList(idx);
        
        % Generate dummy data
        dataMatrix = randn(N, S) + 1i * randn(N, S);
        
        % --- 1. Software Timing ---
        tSum = 0;
        for t = 1:numTrials
            tic;
            out_sw = ifft(dataMatrix, N, 1);
            tSum = tSum + toc;
        end
        timeSoftware(idx) = tSum / numTrials;
        
        % --- 2. Hardware 8-Core Timing (Logical Simulation) ---
        clockFreq = 500e6; % 500 MHz FPGA
        clockPeriod = 1 / clockFreq;
        pipelineLatency = 113 * clockPeriod;
        
        symbolsPerCore = ceil(S / numCores);
        processingTime = symbolsPerCore * N * clockPeriod;
        
        timeHardware(idx) = pipelineLatency + processingTime;
        
        fprintf('Symbols: %6d | SW Time: %8.2f us | HW Time: %8.2f us | Speedup: %.2fx\n', ...
            S, timeSoftware(idx)*1e6, timeHardware(idx)*1e6, timeSoftware(idx)/timeHardware(idx));
    end
    
    save(cacheFile, 'symbolsList', 'N', 'timeSoftware', 'timeHardware');
    disp('Simulation complete. Results cached.');
end

% Plotting
figure('Name', 'Time Complexity Comparison', 'Position', [100, 100, 800, 500]);
loglog(symbolsList, timeSoftware * 1e6, '-o', 'LineWidth', 2, 'DisplayName', 'Software (CPU) O(S*N*logN)');
hold on;
loglog(symbolsList, timeHardware * 1e6, '-s', 'LineWidth', 2, 'DisplayName', 'Hardware 8-Core O(S*N)');

% Add theoretical reference line (N log N scaling scaled to match software start)
ref_S = symbolsList;
ref_time = (ref_S .* (N * log2(N))) * (timeSoftware(1) / (N * log2(N)));
loglog(ref_S, ref_time * 1e6, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5, 'DisplayName', 'Theoretical O(S*N*logN)');

grid on;
xlabel('Number of Symbols (S)');
ylabel('Execution Time (\mu s)');
legend('Location', 'northwest');
title('Time Complexity: CPU vs 8-Core Spatial Parallelism');
saveas(gcf, 'timing_comparison.png');

disp('Demo 07 Complete.');
