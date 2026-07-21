% demo_02_constellations.m
% Plots the floating point and fixed point constellations at a robust SNR

clear; clc; close all;
addpath('../core_engines');

disp('Starting Demo 02: Constellations');
snr = 20; % 20 dB is robust enough to clearly see the constellation
numSymbols = 1e5;

% Floating Point Run
disp('Running Floating Point...');
[~, ~, ~, ~, rxConst_float, ~] = core_ofdm_software(snr, numSymbols, false);

% Fixed Point Run (Q4.12)
disp('Running Fixed Point Q(4.12)...');
[~, ~, ~, ~, rxConst_fixed, ~] = core_ofdm_software(snr, numSymbols, true, 16, 12);

% Generate Ideal 16-QAM Constellation Points
ideal_pts = qammod(0:15, 16, 'UnitAveragePower', true);

figure('Name', 'Constellation Comparison', 'Position', [100, 100, 1000, 500]);
subplot(1,2,1);
scatter(real(rxConst_float), imag(rxConst_float), 10, 'b', 'filled', 'MarkerFaceAlpha', 0.5, 'DisplayName', 'Received (Float)');
hold on;
plot(real(ideal_pts), imag(ideal_pts), 'y.', 'MarkerSize', 20, 'DisplayName', 'Ideal 16-QAM');
grid on; axis square;
title('Floating Point (20 dB SNR)');
xlabel('In-Phase'); ylabel('Quadrature');
legend('Location', 'north');

subplot(1,2,2);
scatter(real(rxConst_fixed), imag(rxConst_fixed), 10, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'DisplayName', 'Received (Fixed)');
hold on;
plot(real(ideal_pts), imag(ideal_pts), 'y.', 'MarkerSize', 20, 'DisplayName', 'Ideal 16-QAM');
grid on; axis square;
title('Fixed Point Q(4.12) (20 dB SNR)');
xlabel('In-Phase'); ylabel('Quadrature');
legend('Location', 'north');

disp('Demo 02 Complete.');
