% demo_01_baseline_software.m
% Demonstrates the baseline Software OFDM Transceiver Chain performance

clear; clc; close all;
addpath('../core_engines');

disp('Starting Demo 01: Baseline Software OFDM');
numSymbols = 1e5;
SNRdB_vec = 0:1:25;
numSNR = length(SNRdB_vec);

BER_float = zeros(1, numSNR);
BER_fixed = zeros(1, numSNR);

disp('Calculating Floating Point and Fixed Point Q(4.12) performance...');
for i = 1:numSNR
    snr = SNRdB_vec(i);
    % Floating Point
    [BER_float(i), ~, ~, ~, ~, ~] = core_ofdm_software(snr, numSymbols);
    % Fixed Point Q(4.12)
    [BER_fixed(i), ~, ~, ~, ~, ~] = core_ofdm_software(snr, numSymbols, true, 16, 12);
    
    fprintf('SNR = %2d dB | Float BER = %g | Fixed BER = %g\n', snr, BER_float(i), BER_fixed(i));
end

figure('Name', 'Software Baseline Performance', 'Position', [100, 100, 700, 500]);
semilogy(SNRdB_vec, BER_float, '-s', 'Color', [0.3010, 0.7450, 0.9330], 'LineWidth', 2, 'MarkerSize', 10, 'DisplayName', 'BER (Floating Point)');
hold on;
semilogy(SNRdB_vec, BER_fixed, '-ro', 'LineWidth', 1.5, 'DisplayName', 'BER (Fixed Point Q4.12)');
grid on;
ylim([1e-5 1]);
xlabel('SNR (dB)');
ylabel('Bit Error Rate (BER)');
legend('Location', 'southwest');
title('Baseline Software OFDM BER: Floating vs Fixed Point');
disp('Demo 01 Complete.');
