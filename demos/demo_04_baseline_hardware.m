% demo_04_baseline_hardware.m
% Validates that the Hardware dsphdl 8-Core architecture matches the baseline float

clear; clc; close all;
addpath('../core_engines');

disp('Starting Demo 04: Hardware Baseline Comparison');

cacheFile = '../cache/demo_04_cache.mat';
if isfile(cacheFile)
    disp('Found cached simulation data. Loading instantly...');
    load(cacheFile);
    for i = 1:length(SNRdB_vec)
        fprintf('SNR = %2d dB | Float BER = %g | SW Fix BER = %g | HW BER = %g\n', SNRdB_vec(i), BER_float(i), BER_sw_fixed(i), BER_hw(i));
    end
else
    disp('Cache not found. Running full hardware simulation (this will take time)...');
    
    numSymbols = 1e4; % Reduced for hardware simulation time
    SNRdB_vec = 0:1:25;
    numSNR = length(SNRdB_vec);

    BER_float = zeros(1, numSNR);
    BER_sw_fixed = zeros(1, numSNR);
    BER_hw = zeros(1, numSNR);

    disp('Calculating Baseline Float and SW Fixed Point...');
    for i = 1:numSNR
        [BER_float(i), ~, ~, ~, ~, ~] = core_ofdm_software(SNRdB_vec(i), numSymbols);
        [BER_sw_fixed(i), ~, ~, ~, ~, ~] = core_ofdm_software(SNRdB_vec(i), numSymbols, true, 16, 12);
    end

    disp('Calculating Hardware 8-Core Parallelism Q(4.12)...');
    for i = 1:numSNR
        [BER_hw(i), ~, ~, ~, ~] = core_ofdm_hardware(SNRdB_vec(i), numSymbols, 16, 12);
        fprintf('SNR = %2d dB | Float BER = %g | SW Fix BER = %g | HW BER = %g\n', SNRdB_vec(i), BER_float(i), BER_sw_fixed(i), BER_hw(i));
    end
    
    % Save to cache
    save(cacheFile, 'SNRdB_vec', 'BER_float', 'BER_sw_fixed', 'BER_hw');
    disp('Simulation complete. Results cached.');
end

% Plotting
figure('Name', 'Hardware Baseline', 'Position', [100, 100, 700, 500]);
semilogy(SNRdB_vec, BER_float, '-k', 'LineWidth', 2, 'DisplayName', 'Floating Point Baseline'); hold on;
semilogy(SNRdB_vec, BER_sw_fixed, '-s', 'Color', [0.3010, 0.7450, 0.9330], 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'Software Fixed Q(4.12)');
semilogy(SNRdB_vec, BER_hw, '-ro', 'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', 'Hardware 8-Core Q(4.12)');
grid on;
ylim([1e-5 1]);
xlabel('SNR (dB)');
ylabel('Bit Error Rate (BER)');
legend('Location', 'southwest');
title('Hardware (dsphdl) Baseline Verification');

disp('Demo 04 Complete.');
