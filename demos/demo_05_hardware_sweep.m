% demo_05_hardware_sweep.m
% Sweeps through fixed-point precisions in Hardware (showing Butterfly Truncation effect)

clear; clc; close all;
addpath('../core_engines');

disp('Starting Demo 05: Hardware Precision Sweep');

cacheFile = '../cache/demo_05_cache.mat';
if isfile(cacheFile)
    disp('Found cached simulation data. Loading instantly...');
    load(cacheFile);
    for fmtIdx = 1:numFormats
        W = formats(fmtIdx, 1);
        F_len = formats(fmtIdx, 2);
        fprintf('\n--- Hardware 8-Core Sweep: Q(%d.%d) ---\n', W-F_len, F_len);
        for iSNR = 1:length(SNRdB_vec)
            fprintf('SNR=%2d dB | HW BER=%g\n', SNRdB_vec(iSNR), BER_results(iSNR, fmtIdx));
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

    % Baseline Float
    disp('Calculating Baseline Float...');
    BER_float = zeros(1, numSNR);
    for i = 1:numSNR
        [BER_float(i), ~, ~, ~, ~, ~] = core_ofdm_software(SNRdB_vec(i), numSymbols);
    end

    BER_results = zeros(numSNR, numFormats);
    for fmtIdx = 1:numFormats
        W = formats(fmtIdx, 1);
        F_len = formats(fmtIdx, 2);
        fprintf('\n--- Hardware 8-Core Sweep: Q(%d.%d) ---\n', W-F_len, F_len);
        
        for iSNR = 1:numSNR
            snr = SNRdB_vec(iSNR);
            [BER_results(iSNR, fmtIdx), ~, ~, ~, ~] = core_ofdm_hardware(snr, numSymbols, W, F_len);
            fprintf('SNR=%2d dB | HW BER=%g\n', snr, BER_results(iSNR, fmtIdx));
        end
    end
    
    % Save to cache
    save(cacheFile, 'SNRdB_vec', 'BER_float', 'BER_results', 'formats', 'numFormats');
    disp('Simulation complete. Results cached.');
end

% Plotting
colors = lines(numFormats);
figure('Name', 'BER Hardware Precision Sweep', 'Position', [100, 100, 700, 500]);
semilogy(SNRdB_vec, BER_float, '-k', 'LineWidth', 2, 'DisplayName', 'Floating Point Baseline'); hold on;
for fmtIdx = 1:numFormats
    W = formats(fmtIdx, 1);
    F_len = formats(fmtIdx, 2);
    name = sprintf('HW 8-Core Q(%d.%d)', W-F_len, F_len);
    semilogy(SNRdB_vec, BER_results(:, fmtIdx), '-o', 'LineWidth', 1.5, 'DisplayName', name, 'Color', colors(fmtIdx,:));
end
grid on;
ylim([1e-5 1]);
xlabel('SNR (dB)');
ylabel('Bit Error Rate (BER)');
legend('Location', 'southwest');
title('BER vs SNR for 8-Core HW Spatial Parallelism');

disp('Demo 05 Complete.');
