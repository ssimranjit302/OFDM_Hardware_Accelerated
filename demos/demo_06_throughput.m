% demo_06_throughput.m
% Calculates and plots the system throughput based on Packet Error Rate for various formats

clear; clc; close all;
addpath('../core_engines');

disp('Starting Demo 06: Hardware Throughput Saturation (Precision Sweep)');

cacheFile = '../cache/demo_06_cache.mat';
if isfile(cacheFile)
    disp('Found cached simulation data. Loading instantly...');
    load(cacheFile);
    for fmtIdx = 1:numFormats
        W = formats(fmtIdx, 1);
        F_len = formats(fmtIdx, 2);
        fprintf('\n--- Hardware 8-Core Throughput: Q(%d.%d) ---\n', W-F_len, F_len);
        for iSNR = 1:length(SNRdB_vec)
            fprintf('SNR = %2d dB | HW Throughput = %.2f Mbps\n', SNRdB_vec(iSNR), throughput_results(iSNR, fmtIdx) / 1e6);
        end
    end
else
    disp('Cache not found. Running full hardware simulation (this will take time)...');
    numSymbols = 1e4; % Reduced for hardware simulation time
    SNRdB_vec = 0:1:25;
    numSNR = length(SNRdB_vec);

    formats = [
        16, 12; % Q(4.12)
        12, 8;  % Q(4.8)
        10, 6;  % Q(4.6)
        8,  4;  % Q(4.4)
    ];
    numFormats = size(formats, 1);

    throughput_results = zeros(numSNR, numFormats);

    for fmtIdx = 1:numFormats
        W = formats(fmtIdx, 1);
        F_len = formats(fmtIdx, 2);
        fprintf('\n--- Hardware 8-Core Throughput: Q(%d.%d) ---\n', W-F_len, F_len);
        
        for i = 1:numSNR
            snr = SNRdB_vec(i);
            [~, ~, ~, ~, ~, throughput_results(i, fmtIdx)] = core_ofdm_hardware(snr, numSymbols, W, F_len);
            fprintf('SNR = %2d dB | HW Throughput = %.2f Mbps\n', snr, throughput_results(i, fmtIdx) / 1e6);
        end
    end
    
    save(cacheFile, 'SNRdB_vec', 'throughput_results', 'formats', 'numFormats');
    disp('Simulation complete. Results cached.');
end

% Theoretical Limit for 16-QAM at 1 Msps
symbolRate = 1e6;
k = log2(16);
maxBitrate = k * symbolRate;
numSNR = length(SNRdB_vec);
theoretical_curve = zeros(1, numSNR);
for i = 1:numSNR
    snrLinear = 10^(SNRdB_vec(i)/10);
    cap = symbolRate * log2(1 + snrLinear);
    if cap > maxBitrate
        theoretical_curve(i) = maxBitrate;
    else
        theoretical_curve(i) = cap;
    end
end

% Plotting
colors = lines(numFormats);
figure('Name', 'System Throughput Sweep', 'Position', [100, 100, 700, 500]);
plot(SNRdB_vec, theoretical_curve/1e6, '-k', 'LineWidth', 2, 'DisplayName', 'Theoretical Capacity');
hold on;
for fmtIdx = 1:numFormats
    W = formats(fmtIdx, 1);
    F_len = formats(fmtIdx, 2);
    name = sprintf('HW 8-Core Q(%d.%d)', W-F_len, F_len);
    plot(SNRdB_vec, throughput_results(:, fmtIdx)/1e6, '-o', 'LineWidth', 1.5, 'DisplayName', name, 'Color', colors(fmtIdx,:));
end
grid on;
xlabel('SNR (dB)');
ylabel('Throughput (Mbps)');
legend('Location', 'southeast');
title('Hardware System Throughput vs Channel SNR (Precision Sweep)');

disp('Demo 06 Complete.');
